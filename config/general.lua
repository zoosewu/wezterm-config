return {
   automatically_reload_config = true,
   exit_behavior = 'CloseOnCleanExit',
   exit_behavior_messaging = 'Verbose',
   status_update_interval = 1000,
   audible_bell = 'Disabled',

   scrollback_lines = 20000,

   hyperlink_rules = {
      { regex = '\\((\\w+://\\S+)\\)',    format = '$1', highlight = 1 },
      { regex = '\\[(\\w+://\\S+)\\]',    format = '$1', highlight = 1 },
      { regex = '\\{(\\w+://\\S+)\\}',    format = '$1', highlight = 1 },
      { regex = '<(\\w+://\\S+)>',         format = '$1', highlight = 1 },
      -- Bare URLs: end on word char, slash, %, +, ], or ) (exclude opening delimiters and punctuation)
      {
         regex = '\\b\\w+://[\\w/%+\\-=@#?&\\[\\](){}.,;:!*~$\']+[\\w/%+\\])]',
         format = '$0',
      },
      { regex = '\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b', format = 'mailto:$0' },
   },
}
