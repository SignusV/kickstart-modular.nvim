vim.opt.termguicolors = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.smarttab = true

-- The Vue language server's semantic tokens override Tree-sitter's injected
-- TypeScript highlighting inside Vue template expressions. Disable semantic
-- tokens only for Vue buffers so Tree-sitter controls the syntax colors,
-- while preserving completion, diagnostics, navigation, and other LSP features.
vim.api.nvim_create_autocmd('LspAttach', {
  desc = 'Disable LSP semantic tokens for Vue files',
  callback = function(event)
    if vim.bo[event.buf].filetype ~= 'vue' then
      return
    end

    local client = vim.lsp.get_client_by_id(event.data.client_id)

    if client then
      vim.lsp.semantic_tokens.enable(false, {
        bufnr = event.buf,
        client_id = client.id,
      })
    end
  end,
})
