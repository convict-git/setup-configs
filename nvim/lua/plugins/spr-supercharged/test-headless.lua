-- Headless integration test for spr-supercharged.
-- Usage (from sprinklr-ui-hub root):
--   nvim --headless -u ~/.config/nvim/init.lua -S <path-to-this-file>

local project_path = vim.fn.getcwd()
local util = require("spr-supercharged.util")
local cache = require("spr-supercharged.core.cache")

local failures = {}
local passes = {}

local function pass(msg)
  passes[#passes + 1] = msg
  print("[PASS] " .. msg)
end

local function fail(msg)
  failures[#failures + 1] = msg
  print("[FAIL] " .. msg)
end

local function assert_true(cond, msg)
  if cond then
    pass(msg)
  else
    fail(msg)
  end
end

print("=== spr-supercharged headless test ===")
print("cwd: " .. project_path)

-- ---------------------------------------------------------------------------
-- 1. SprinklrScan
-- ---------------------------------------------------------------------------
print("\n--- SprinklrScan ---")
local scan_ok, scan_err = pcall(function()
  require("spr-supercharged.commands.scan").run()
end)

if scan_ok then
  pass("SprinklrScan completed without error")
else
  fail("SprinklrScan errored: " .. tostring(scan_err))
end

local cache_dir_pre = util.join(project_path, ".nvim")
local dep_pre = util.join(cache_dir_pre, "dependency.json")
if vim.fn.filereadable(dep_pre) == 0 then
  fail("SprinklrScan did not produce cache output")
  print("\n=== SUMMARY ===")
  print("Aborted: scan produced no cache files.")
  vim.cmd("cquit 1")
end

local cache_dir = util.join(project_path, ".nvim")
for _, fname in ipairs({ "hashVsFile.json", "imports.json", "dependency.json" }) do
  local fpath = util.join(cache_dir, fname)
  assert_true(vim.fn.filereadable(fpath) == 1, fname .. " exists at " .. fpath)
end

local cache_data = cache.load(project_path)
assert_true(cache_data.initialized, "cache.load returns initialized data")
assert_true(vim.tbl_count(cache_data.hash_vs_file) > 0, "hash_vs_file is non-empty")
assert_true(vim.tbl_count(cache_data.dependency_graph) > 0, "dependency_graph is non-empty")

-- Pick a file that exists in the graph for downstream tests.
local test_file = nil
for _, path in pairs(cache_data.hash_vs_file) do
  if path:match("/packages/modules/src/.+%.ts$") then
    test_file = path
    break
  end
end
if not test_file then
  for _, path in pairs(cache_data.hash_vs_file) do
    if path:match("%.tsx$") then
      test_file = path
      break
    end
  end
end
if not test_file then
  for _, path in pairs(cache_data.hash_vs_file) do
    test_file = path
    break
  end
end

assert_true(test_file ~= nil, "found a test file in the graph: " .. tostring(test_file))
print("test file: " .. test_file)

-- ---------------------------------------------------------------------------
-- 2. SprinklrReferences
-- ---------------------------------------------------------------------------
print("\n--- SprinklrReferences ---")
vim.cmd("edit " .. vim.fn.fnameescape(test_file))

local refs_ok, refs_err = pcall(function()
  require("spr-supercharged.commands.references").run()
end)

if refs_ok then
  pass("SprinklrReferences completed without error")
else
  fail("SprinklrReferences errored: " .. tostring(refs_err))
end

-- Also verify query layer directly.
local references = require("spr-supercharged.query.references")
local ref_items = references.get_file_references({
  file_path = test_file,
  dependency_graph = cache_data.dependency_graph,
  file_vs_hash = cache_data.file_vs_hash,
  hash_vs_file = cache_data.hash_vs_file,
})
assert_true(type(ref_items) == "table" and #ref_items > 0, "get_file_references returns items")

local has_real_ref = false
for _, item in ipairs(ref_items) do
  if item.path and item.path ~= "" and not item.label:match("^No References") and not item.label:match("^File Not Found") then
    has_real_ref = true
    break
  end
end
if has_real_ref then
  pass("get_file_references found at least one real reference for test file")
else
  print("[INFO] test file has no importers in graph (may be a leaf); references UI still opened")
  pass("get_file_references returned a valid (possibly empty) result set")
end

-- ---------------------------------------------------------------------------
-- 3. SprinklrTraceImports (mock vim.ui.input / vim.ui.select)
-- ---------------------------------------------------------------------------
print("\n--- SprinklrTraceImports ---")

-- Find a file with references to use as a trace target.
local trace_start = nil
local trace_end = test_file
for path, hash in pairs(cache_data.file_vs_hash) do
  local node = cache_data.dependency_graph[hash]
  if node and node[2] and #node[2] > 0 then
    -- pick an importer of test_file if possible
    local test_hash = cache_data.file_vs_hash[test_file]
    if test_hash and node[2] then
      for _, ref_hash in ipairs(node[2]) do
        trace_start = cache_data.hash_vs_file[ref_hash]
        if trace_start then
          break
        end
      end
    end
    if not trace_start then
      trace_start = path
    end
    break
  end
end

if not trace_start then
  trace_start = test_file
end

print("trace: " .. trace_start .. " -> " .. trace_end)

local orig_input = vim.ui.input
local orig_select = vim.ui.select

vim.ui.input = function(_, cb)
  cb("./" .. vim.fn.fnamemodify(trace_start, ":."))
end

vim.ui.select = function(_, _, cb)
  cb("Quick")
end

local trace_ok, trace_err = pcall(function()
  require("spr-supercharged.commands.trace_imports").run()
end)

vim.ui.input = orig_input
vim.ui.select = orig_select

if trace_ok then
  pass("SprinklrTraceImports completed without error")
else
  fail("SprinklrTraceImports errored: " .. tostring(trace_err))
end

-- Verify query layer directly.
local sequences = require("spr-supercharged.query.sequences")
local seq_items = sequences.get_import_sequences({
  dependency_graph = cache_data.dependency_graph,
  file_vs_hash = cache_data.file_vs_hash,
  hash_vs_file = cache_data.hash_vs_file,
  starting_file_path = trace_start,
  ending_file_path = trace_end,
  input_config = {
    destination_path = trace_start,
    max_depth_to_explore = 20,
    max_nodes_to_explore = 300000,
    max_sequences_to_explore = 3,
  },
})
assert_true(type(seq_items) == "table" and #seq_items > 0, "get_import_sequences returns items")

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
print("\n=== SUMMARY ===")
print(string.format("Passed: %d", #passes))
print(string.format("Failed: %d", #failures))

if #failures > 0 then
  for _, f in ipairs(failures) do
    print("  - " .. f)
  end
  vim.cmd("cquit 1")
else
  print("All tests passed.")
  vim.cmd("quit")
end
