return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      table.insert(opts.cmd, "--jvm-arg=-Xms128m")
      table.insert(opts.cmd, "--jvm-arg=-Xmx512m")
      return opts
    end,
  },
}
