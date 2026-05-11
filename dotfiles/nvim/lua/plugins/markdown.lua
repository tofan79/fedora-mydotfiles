-- ================================================================================================
-- TITLE: markdown.nvim
-- ABOUT: Markdown editing enhancements (tables, checkboxes, lists)
-- LINKS: markdown.nvim    https://github.com/tadmccorkle/markdown.nvim
-- ================================================================================================
return {
  "tadmccorkle/markdown.nvim",
  ft = "markdown",
  opts = {
    -- Checkbox options
    checkbox = {
      enabled = true,
    },
    -- Table options
    table = {
      enabled = true,
    },
  },
}
