return {
	{
		"Skardyy/neo-img",
		dependencies = { "stevearc/oil.nvim" },
		lazy = false,
		config = function()
			local ttyimg = vim.fn.exepath("ttyimg")
			if ttyimg == "" then
				ttyimg = vim.fn.expand("~/.local/bin/ttyimg")
			end

			require("neo-img").setup({
				auto_open = true,
				oil_preview = true,
				backend = "kitty",
				ttyimg = "global",
				bin_path = ttyimg,
				size = "80%",
				center = true,
			})

			local function clear_images()
				local seq = "\27_Ga=d,d=A,q=2\27\\"
				if vim.env.TMUX and vim.env.TMUX ~= "" then
					seq = "\27Ptmux;" .. seq:gsub("\27", "\27\27") .. "\27\\"
				end
				pcall(vim.fn.chansend, vim.v.stderr, seq)
			end

			-- Writing through the pane's stderr only works while that pane is
			-- visible. When tmux switches tabs the pane is already inactive, so
			-- write the delete sequence straight to the attached client instead.
			local function clear_images_direct()
				local seq = "\27_Ga=d,d=A,q=2\27\\"
				if vim.env.TMUX and vim.env.TMUX ~= "" then
					local ok, out = pcall(vim.fn.system, { "tmux", "display-message", "-p", "#{client_tty}" })
					if ok and vim.v.shell_error == 0 then
						local tty = out:gsub("%s+$", "")
						local wrote = false
						if tty ~= "" then
							wrote = pcall(function()
								local file = assert(io.open(tty, "w"))
								file:write(seq)
								file:close()
							end)
						end
						if wrote then
							return
						end
					end
				end
				clear_images()
			end

			local image = require("neo-img.image")
			if not image._cleanup_patched then
				image._cleanup_patched = true
				local delete = image.Delete
				image.Delete = function()
					local had_image = image.Should_Clean()
					delete()
					if had_image then
						clear_images()
					end
					image.draw = {}
					image._focus_suspended = false
				end
			end

			local oil = require("oil")
			if not oil._neo_img_cleanup_patched then
				oil._neo_img_cleanup_patched = true
				local open_preview = oil.open_preview
				oil.open_preview = function(...)
					image.StopJob()
					if image.Should_Clean() then
						clear_images()
					end
					image.draw = {}
					image._focus_suspended = false
					return open_preview(...)
				end
			end

			local cleanup_group = vim.api.nvim_create_augroup("NeoImgCleanup", { clear = true })

			vim.api.nvim_create_autocmd("BufEnter", {
				group = cleanup_group,
				callback = function()
					if image.Should_Clean() then
						clear_images()
					end
					image.draw = {}
					image._focus_suspended = false
				end,
			})

			vim.api.nvim_create_autocmd("FocusLost", {
				group = cleanup_group,
				callback = function()
					image.StopJob()
					local had_image = image.Should_Clean()
					if had_image then
						clear_images_direct()
					end
					image.draw = {}
					image._focus_suspended = had_image
				end,
			})

			vim.api.nvim_create_autocmd("FocusGained", {
				group = cleanup_group,
				callback = function()
					if not image._focus_suspended then
						return
					end
					image._focus_suspended = false
					if not image.esc or image.esc == "" or not image.win then
						return
					end
					vim.defer_fn(function()
						if image.esc and image.esc ~= "" and image.win and vim.api.nvim_win_is_valid(image.win) then
							image.Draw()
						end
					end, 300)
				end,
			})

			vim.api.nvim_create_autocmd("VimLeavePre", {
				group = cleanup_group,
				callback = function()
					image.StopJob()
					if image.Should_Clean() then
						clear_images()
					end
					image.draw = {}
					image._focus_suspended = false
				end,
			})
		end,
	},
}
