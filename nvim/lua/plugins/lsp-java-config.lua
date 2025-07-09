local module = {}

local function get_jdtls()
    -- Get the Mason Registry to gain access to downloaded binaries
    local mason_registry = require("mason-registry")
    -- Find the JDTLS package in the Mason Regsitry
    local jdtls = mason_registry.get_package("jdtls")
    -- Find the full path to the directory where Mason has downloaded the JDTLS binaries
    local jdtls_path = vim.fn.expand("$MASON/packages/jdtls/")
    -- Obtain the path to the jar which runs the language server
    local launcher = vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar")
     -- Declare white operating system we are using, windows use win, macos use mac
    local SYSTEM = "mac_arm"
    -- Obtain the path to configuration files for your specific operating system
    local config = jdtls_path .. "/config_" .. SYSTEM
    -- Obtain the path to the Lomboc jar
    local lombok = jdtls_path .. "/lombok.jar"
    return launcher, config, lombok
end

local function get_bundles()
    -- Get the Mason Registry to gain access to downloaded binaries
    local mason_registry = require("mason-registry")
    -- Find the Java Debug Adapter package in the Mason Registry
    local java_debug = mason_registry.get_package("java-debug-adapter")
    -- Obtain the full path to the directory where Mason has downloaded the Java Debug Adapter binaries
    local java_debug_path = vim.fn.expand("$MASON/packages/java-debug-adapter/")

    local bundles = {
        vim.fn.glob(java_debug_path .. "/extension/server/com.microsoft.java.debug.plugin-*.jar", true)
    }

    -- Find the Java Test package in the Mason Registry
    local java_test = mason_registry.get_package("java-test")
    -- Obtain the full path to the directory where Mason has downloaded the Java Test binaries
    local java_test_path = vim.fn.expand("$MASON/packages/java-test/")
     -- Add all of the Jars for running tests in debug mode to the bundles list
     vim.list_extend(bundles, vim.split(vim.fn.glob(java_test_path .. "/extension/server/*.jar", true), "\n"))

     return bundles
end

local function get_workspace()
    -- Get the home directory of your operating system
    local home = os.getenv "HOME"
    -- Declare a directory where you would like to store project information
    local workspace_path = home .. "/code/workspace/"
    -- Determine the project name
    local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
    -- Create the workspace directory by concatenating the designated workspace path and the project name
    local workspace_dir = workspace_path .. project_name
    return workspace_dir
end

local function java_keymaps()
    -- Allow yourself to run JdtCompile as a Vim command
    vim.cmd("command! -buffer -nargs=? -complete=custom,v:lua.require'jdtls'._complete_compile JdtCompile lua require('jdtls').compile(<f-args>)")
    -- Allow yourself/register to run JdtUpdateConfig as a Vim command
    vim.cmd("command! -buffer JdtUpdateConfig lua require('jdtls').update_project_config()")
    -- Allow yourself/register to run JdtBytecode as a Vim command
    vim.cmd("command! -buffer JdtBytecode lua require('jdtls').javap()")
    -- Allow yourself/register to run JdtShell as a Vim command
    vim.cmd("command! -buffer JdtJshell lua require('jdtls').jshell()")

    -- Set a Vim motion to <Space> + <Shift>J + o to organize imports in normal mode
    vim.keymap.set('n', '<leader>Jo', "<Cmd> lua require('jdtls').organize_imports()<CR>", { desc = "[J]ava [O]rganize Imports" })
    -- Set a Vim motion to <Space> + <Shift>J + v to extract the code under the cursor to a variable
    vim.keymap.set('n', '<leader>Jv', "<Cmd> lua require('jdtls').extract_variable()<CR>", { desc = "[J]ava Extract [V]ariable" })
    -- Set a Vim motion to <Space> + <Shift>J + v to extract the code selected in visual mode to a variable
    vim.keymap.set('v', '<leader>Jv', "<Esc><Cmd> lua require('jdtls').extract_variable(true)<CR>", { desc = "[J]ava Extract [V]ariable" })
    -- Set a Vim motion to <Space> + <Shift>J + <Shift>C to extract the code under the cursor to a static variable
    vim.keymap.set('n', '<leader>JC', "<Cmd> lua require('jdtls').extract_constant()<CR>", { desc = "[J]ava Extract [C]onstant" })
    -- Set a Vim motion to <Space> + <Shift>J + <Shift>C to extract the code selected in visual mode to a static variable
    vim.keymap.set('v', '<leader>JC', "<Esc><Cmd> lua require('jdtls').extract_constant(true)<CR>", { desc = "[J]ava Extract [C]onstant" })
    -- Set a Vim motion to <Space> + <Shift>J + t to run the test method currently under the cursor
    vim.keymap.set('n', '<leader>Jt', "<Cmd> lua require('jdtls').test_nearest_method()<CR>", { desc = "[J]ava [T]est Method" })
    -- Set a Vim motion to <Space> + <Shift>J + t to run the test method that is currently selected in visual mode
    vim.keymap.set('v', '<leader>Jt', "<Esc><Cmd> lua require('jdtls').test_nearest_method(true)<CR>", { desc = "[J]ava [T]est Method" })
    -- Set a Vim motion to <Space> + <Shift>J + <Shift>T to run an entire test suite (class)
    vim.keymap.set('n', '<leader>JT', "<Cmd> lua require('jdtls').test_class()<CR>", { desc = "[J]ava [T]est Class" })
    -- Set a Vim motion to <Space> + <Shift>J + u to update the project configuration
    vim.keymap.set('n', '<leader>Ju', "<Cmd> JdtUpdateConfig<CR>", { desc = "[J]ava [U]pdate Config" })
end

local function setup_jdtls()
    -- Get access to the jdtls plugin and all of its functionality
    local jdtls = require "jdtls"

    -- Get the paths to the jdtls jar, operating specific configuration directory, and lombok jar
    local launcher, os_config, lombok = get_jdtls()

    -- Get the path you specified to hold project information
    local workspace_dir = get_workspace()

    -- Get the bundles list with the jars to the debug adapter, and testing adapters
    local bundles = get_bundles()

    -- Determine the root directory of the project by looking for these specific markers
    local root_dir = jdtls.setup.find_root({ '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle' });

    -- Tell our JDTLS language features it is capable of
    local capabilities = {
        workspace = {
            configuration = true
        },
        textDocument = {
            completion = {
                snippetSupport = false
            }
        }
    }

    local lsp_capabilities = require("cmp_nvim_lsp").default_capabilities()

    for k,v in pairs(lsp_capabilities) do capabilities[k] = v end

    -- Get the default extended client capablities of the JDTLS language server
    local extendedClientCapabilities = jdtls.extendedClientCapabilities
    -- Modify one property called resolveAdditionalTextEditsSupport and set it to true
    extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

    -- Set the command that starts the JDTLS language server jar
    local cmd = {
        'java',
        '-Declipse.application=org.eclipse.jdt.ls.core.id1',
        '-Dosgi.bundles.defaultStartLevel=4',
        '-Declipse.product=org.eclipse.jdt.ls.core.product',
        '-Dlog.protocol=true',
        '-Dlog.level=ALL',
        '-Xmx20000m',
        -- '-XX:MaxPermSize=12512m',
        '-Dsun.nio.fs.fileDescriptorsLimit=65536',
        '--add-modules=ALL-SYSTEM',
        '--add-opens', 'java.base/java.io=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang.annotation=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang.constant=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang.invoke=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang.module=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang.ref=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang.reflect=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang.runtime=ALL-UNNAMED',
        '--add-opens', 'java.base/java.math=ALL-UNNAMED',
        '--add-opens', 'java.base/java.net=ALL-UNNAMED',
        '--add-opens', 'java.base/java.net.spi=ALL-UNNAMED',
        '--add-opens', 'java.base/java.nio=ALL-UNNAMED',
        '--add-opens', 'java.base/java.nio.channels=ALL-UNNAMED',
        '--add-opens', 'java.base/java.nio.channels.spi=ALL-UNNAMED',
        '--add-opens', 'java.base/java.nio.charset=ALL-UNNAMED',
        '--add-opens', 'java.base/java.nio.charset.spi=ALL-UNNAMED',
        '--add-opens', 'java.base/java.nio.file=ALL-UNNAMED',
        '--add-opens', 'java.base/java.nio.file.attribute=ALL-UNNAMED',
        '--add-opens', 'java.base/java.nio.file.spi=ALL-UNNAMED',
        '--add-opens', 'java.base/java.security=ALL-UNNAMED',
        '--add-opens', 'java.base/java.security.cert=ALL-UNNAMED',
        '--add-opens', 'java.base/java.security.interfaces=ALL-UNNAMED',
        '--add-opens', 'java.base/java.security.spec=ALL-UNNAMED',
        '--add-opens', 'java.base/java.text=ALL-UNNAMED',
        '--add-opens', 'java.base/java.text.spi=ALL-UNNAMED',
        '--add-opens', 'java.base/java.time=ALL-UNNAMED',
        '--add-opens', 'java.base/java.time.chrono=ALL-UNNAMED',
        '--add-opens', 'java.base/java.time.format=ALL-UNNAMED',
        '--add-opens', 'java.base/java.time.temporal=ALL-UNNAMED',
        '--add-opens', 'java.base/java.time.zone=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util.concurrent=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util.concurrent.atomic=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util.concurrent.locks=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util.function=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util.jar=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util.random=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util.regex=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util.spi=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util.stream=ALL-UNNAMED',
        '--add-opens', 'java.base/java.util.zip=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.crypto=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.crypto.interfaces=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.crypto.spec=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.net=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.net.ssl=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.security.auth=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.security.auth.callback=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.security.auth.login=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.security.auth.spi=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.security.auth.x500=ALL-UNNAMED',
        '--add-opens', 'java.base/javax.security.cert=ALL-UNNAMED',
        '--add-opens', 'java.xml/com.sun.org.apache.xerces.internal.parsers=ALL-UNNAMED',
        '--add-opens', 'java.xml/com.sun.org.apache.xerces.internal.util=ALL-UNNAMED',
        '--add-opens', 'java.base/jdk.internal.ref=ALL-UNNAMED',
        '--add-opens', 'java.base/sun.net.www=ALL-UNNAMED',
        '--add-opens', 'java.base/sun.nio.ch=ALL-UNNAMED',
        '--add-opens', 'java.base/sun.net.www.protocol.https=ALL-UNNAMED',
        '--add-opens', 'java.base/sun.util.calendar=ALL-UNNAMED',
        '--add-opens', 'java.base/sun.util.locale.provider=ALL-UNNAMED',
        '--add-opens', 'java.desktop/java.beans=ALL-UNNAMED',
        '--add-opens', 'java.scripting/javax.script=ALL-UNNAMED',
        '-javaagent:' .. lombok,
        '-jar',
        launcher,
        '-configuration',
        os_config,
        '-data',
        workspace_dir
    }

     -- Configure settings in the JDTLS server
    local settings = {
        java = {
            -- Enable code formatting
            format = {
                enabled = true,
                -- Use the Google Style guide for code formattingh
                settings = {
                    url = vim.fn.stdpath("config") .. "/lang_servers/intellij-java-google-style.xml",
                    profile = "GoogleStyle"
                }
            },
            -- Enable downloading archives from eclipse automatically
            eclipse = {
                downloadSource = true
            },
            -- Enable downloading archives from maven automatically
            maven = {
                downloadSources = true
            },
            -- Enable method signature help
            signatureHelp = {
                enabled = true
            },
            -- Use the fernflower decompiler when using the javap command to decompile byte code back to java code
            contentProvider = {
                preferred = "fernflower"
            },
            -- Setup automatical package import oranization on file save
            saveActions = {
                organizeImports = true
            },
            -- Customize completion options
            completion = {
                -- When using an unimported static method, how should the LSP rank possible places to import the static method from
                favoriteStaticMembers = {
                    "org.hamcrest.MatcherAssert.assertThat",
                    "org.hamcrest.Matchers.*",
                    "org.hamcrest.CoreMatchers.*",
                    "org.junit.jupiter.api.Assertions.*",
                    "java.util.Objects.requireNonNull",
                    "java.util.Objects.requireNonNullElse",
                    "org.mockito.Mockito.*",
                },
                -- Try not to suggest imports from these packages in the code action window
                filteredTypes = {
                    "com.sun.*",
                    "io.micrometer.shaded.*",
                    "java.awt.*",
                    "jdk.*",
                    "sun.*",
                },
                -- Set the order in which the language server should organize imports
                importOrder = {
                    "java",
                    "jakarta",
                    "javax",
                    "com",
                    "org",
                }
            },
            sources = {
                -- How many classes from a specific package should be imported before automatic imports combine them all into a single import
                organizeImports = {
                    starThreshold = 9999,
                    staticThreshold = 9999
                }
            },
            -- How should different pieces of code be generated?
            codeGeneration = {
                -- When generating toString use a json format
                toString = {
                    template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}"
                },
                -- When generating hashCode and equals methods use the java 7 objects method
                hashCodeEquals = {
                    useJava7Objects = true
                },
                -- When generating code use code blocks
                useBlocks = true
            },
             -- If changes to the project will require the developer to update the projects configuration advise the developer before accepting the change

            import = { gradle = { wrapper = { enabled = true } , offline = { enabled = true }} },
            configuration = {
                updateBuildConfiguration = "disabled",
                runtimes = {
                  {
                    name = "JavaSE-21",
                    path = "/Users/priyanshu.shrivastav/Library/Java/JavaVirtualMachines/corretto-21.0.5/Contents/Home",
                    default = true,
                  }
                }
            },
            -- enable code lens in the lsp
            referencesCodeLens = {
                enabled = true
            },
            -- enable inlay hints for parameter names,
            inlayHints = {
                parameterNames = {
                    enabled = "all"
                }
            }
        }
    }

    -- Create a table called init_options to pass the bundles with debug and testing jar, along with the extended client capablies to the start or attach function of JDTLS
    local init_options = {
        bundles = bundles,
        extendedClientCapabilities = extendedClientCapabilities
    }

    -- Function that will be ran once the language server is attached
    local on_attach = function(_, bufnr)
        -- Map the Java specific key mappings once the server is attached
        java_keymaps()

        -- Setup the java debug adapter of the JDTLS server
        require('jdtls.dap').setup_dap()

        -- Find the main method(s) of the application so the debug adapter can successfully start up the application
        -- Sometimes this will randomly fail if language server takes to long to startup for the project, if a ClassDefNotFoundException occurs when running
        -- the debug tool, attempt to run the debug tool while in the main class of the application, or restart the neovim instance
        -- Unfortunately I have not found an elegant way to ensure this works 100%
        require('jdtls.dap').setup_dap_main_class_configs()
        -- Enable jdtls commands to be used in Neovim
        require 'jdtls.setup'.add_commands()
        -- Refresh the codelens
        -- Code lens enables features such as code reference counts, implemenation counts, and more.
        vim.lsp.codelens.refresh()

        -- Setup a function that automatically runs every time a java file is saved to refresh the code lens
        vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = { "*.java" },
            callback = function()
                local _, _ = pcall(vim.lsp.codelens.refresh)
            end
        })
    end

    -- Create the configuration table for the start or attach function
    local config = {
        cmd = cmd,
        root_dir = root_dir,
        settings = settings,
        capabilities = capabilities,
        init_options = init_options,
        on_attach = on_attach
    }

    -- Start the JDTLS server
    require('jdtls').start_or_attach(config)
end

local function sprint_boot_config()
    -- gain acces to the springboot nvim plugin and its functions
    local springboot_nvim = require("springboot-nvim")

    -- set a vim motion to <Space> + <Shift>J + r to run the spring boot project in a vim terminal
    vim.keymap.set('n', '<leader>Jr', springboot_nvim.boot_run, {desc = "[J]ava [R]un Spring Boot"})
    -- set a vim motion to <Space> + <Shift>J + c to open the generate class ui to create a class
    vim.keymap.set('n', '<leader>Jc', springboot_nvim.generate_class, {desc = "[J]ava Create [C]lass"})
    -- set a vim motion to <Space> + <Shift>J + i to open the generate interface ui to create an interface
    vim.keymap.set('n', '<leader>Ji', springboot_nvim.generate_interface, {desc = "[J]ava Create [I]nterface"})
    -- set a vim motion to <Space> + <Shift>J + e to open the generate enum ui to create an enum
    vim.keymap.set('n', '<leader>Je', springboot_nvim.generate_enum, {desc = "[J]ava Create [E]num"})

    -- run the setup function with default configuration
    springboot_nvim.setup({})
end

module.get = function(disabled)
  return {
    "mason-org/mason-lspconfig.nvim",
    cond = function()
      return not disabled
    end,
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      { "hrsh7th/cmp-nvim-lsp" },
      {
        "elmcgill/springboot-nvim",
        dependencies = {
            "neovim/nvim-lspconfig",
            "mfussenegger/nvim-jdtls"
        },
        config = sprint_boot_config,
      },
      "neovim/nvim-lspconfig",
      {
        "jay-babu/mason-nvim-dap.nvim",
        config = function()
          require('mason-nvim-dap').setup({
            ensure_installed = { 'java-debug-adapter', 'java-test' },
          })
        end,
      },
      {
        "mfussenegger/nvim-jdtls",
        config = function()
          vim.defer_fn(function()
            print('Calling setup_jdtls ...')
            setup_jdtls()
          end, 50)
        end,
      },
      {
        "neovim/nvim-lspconfig",
        config = function()
          local lspconfig = require('lspconfig')
          -- todo later add more lsp keymaps
          vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Code [G]oto [D]efinition" })
        end,
      },
    },
    config = function()
      require('mason-lspconfig').setup({
        ensure_installed = { "jdtls" },
      })
    end,
  }
end

return module

