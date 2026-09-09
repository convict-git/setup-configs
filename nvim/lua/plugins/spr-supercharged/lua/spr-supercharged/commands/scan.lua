local cache = require("spr-supercharged.core.cache")
local config = require("spr-supercharged.config")
local graph = require("spr-supercharged.core.graph")
local parser = require("spr-supercharged.core.parser")
local progress = require("spr-supercharged.ui.progress")
local scanner = require("spr-supercharged.core.scanner")
local util = require("spr-supercharged.util")

local M = {}

local SCAN_WEIGHT = 25
local PARSE_WEIGHT = 65
local GRAPH_WEIGHT = 5

function M.run()
  local project_path = util.get_project_path()
  if not project_path then
    util.notify_error("No workspace folder found. Please open a project folder.")
    return
  end

  local opts = config.get()
  local directories = vim.tbl_map(function(directory)
    local rel = directory:gsub("^%./", "")
    return util.normalize(util.join(project_path, rel))
  end, opts.directories)

  local total_start = vim.loop.hrtime()
  progress.start("Scanning project files")

  local scan_start = vim.loop.hrtime()
  local scan_result = scanner.scan(directories, function(done, total, label)
    local pct = math.floor((done / total) * SCAN_WEIGHT)
    progress.update(pct, string.format("(%d/%d) %s", done, total, label), "Scanning project files")
  end)

  local files = scan_result.files
  local file_vs_hash = scan_result.file_vs_hash
  local hash_vs_file = scan_result.hash_vs_file
  local scan_secs = (vim.loop.hrtime() - scan_start) / 1e9

  if #files == 0 then
    util.notify_error("No files found in the project. Please check the directories.")
    return
  end

  progress.update(
    SCAN_WEIGHT,
    string.format("Found %d files in %.1fs", #files, scan_secs),
    "Scanning project files"
  )

  local parse_start = vim.loop.hrtime()
  progress.start("Parsing imports")

  local imports = parser.parse_imports_in_files(files, file_vs_hash, project_path, function(done, total, label)
    local pct = SCAN_WEIGHT + math.floor((done / total) * PARSE_WEIGHT)
    progress.update(pct, label, "Parsing imports")
  end)

  local parse_secs = (vim.loop.hrtime() - parse_start) / 1e9
  progress.update(
    SCAN_WEIGHT + PARSE_WEIGHT,
    string.format("%d files with imports in %.1fs", vim.tbl_count(imports), parse_secs),
    "Parsing imports"
  )

  progress.start("Building dependency graph")
  local graph_start = vim.loop.hrtime()
  local dependency_graph = graph.build_dependency_graph(files, imports, file_vs_hash)
  local graph_secs = (vim.loop.hrtime() - graph_start) / 1e9

  progress.update(
    SCAN_WEIGHT + PARSE_WEIGHT + GRAPH_WEIGHT,
    string.format("Built in %.2fs", graph_secs),
    "Building dependency graph"
  )

  progress.start("Saving results")
  cache.save(project_path, hash_vs_file, imports, dependency_graph, { quiet = true })

  local total_secs = (vim.loop.hrtime() - total_start) / 1e9
  progress.finish(string.format(
    "Indexed %d files in %.1fs — saved to .nvim/",
    #files,
    total_secs
  ))
end

return M
