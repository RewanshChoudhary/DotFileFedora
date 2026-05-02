return {
  {
    "snacks.nvim",
    opts = function(_, opts)
      opts.dashboard = opts.dashboard or {}
      opts.dashboard.preset = opts.dashboard.preset or {}
      opts.dashboard.width = 90

      opts.dashboard.preset.header = [[ 
        ███▄▄▄▄      ▄████████  ▄██████▄   ▄█    █▄   ▄█    ▄▄▄▄███▄▄▄▄   
        ███▀▀▀██▄   ███    ███ ███    ███ ███    ███ ███  ▄██▀▀▀███▀▀▀██▄ 
        ███   ███   ███    █▀  ███    ███ ███    ███ ███▌ ███   ███   ███ 
        ███   ███  ▄███▄▄▄     ███    ███ ███    ███ ███▌ ███   ███   ███ 
        ███   ███ ▀▀███▀▀▀     ███    ███ ███    ███ ███▌ ███   ███   ███ 
        ███   ███   ███    █▄  ███    ███ ███    ███ ███  ███   ███   ███ 
        ███   ███   ███    ███ ███    ███ ███    ███ ███  ███   ███   ███ 
         ▀█   █▀    ██████████  ▀██████▀   ▀██████▀  █▀    ▀█   ███   █▀  
                                                                          
          ]]
      opts.dashboard.sections = {
        { section = "header", align = "center", padding = { 2, 2 } },
        { section = "keys", gap = 2, padding = 1 },
        { section = "startup" },
      }
    end,
  },
}
