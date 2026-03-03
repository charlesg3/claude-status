-- tests/test-vim.lua
-- Headless Neovim tests for the claude-status Lua plugin.
--
-- Tests the pure-Lua surface: highlight group setup, sessions API,
-- statusline formatting, bell behaviour, and nvim_active state file patching.
--
-- register() relies on PID-walking to find a terminal buffer, which is not
-- possible in headless mode.  Where needed we bypass it by injecting directly
-- into sessions._buf_sessions (the same table the real code uses).
--
-- Usage:
--   nvim --headless -l tests/test-vim.lua
--   bash scripts/run-tests.sh --vim
--
-- Requires Neovim 0.10+.

local PASS = 0
local FAIL = 0

local function ok(name, cond, msg)
  if cond then
    io.write(string.format("  \27[32m✓\27[0m %s\n", name))
    PASS = PASS + 1
  else
    io.write(string.format("  \27[31m✗\27[0m %s%s\n",
      name, msg and (" — " .. tostring(msg)) or ""))
    FAIL = FAIL + 1
  end
end

local function section(name)
  io.write(string.format("\n\27[1m%s\27[0m\n", name))
end

-- ---------------------------------------------------------------------------
-- Bootstrap: add plugin root to runtimepath
-- ---------------------------------------------------------------------------
local plugin_dir = vim.fn.fnamemodify(
  debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(plugin_dir)

-- ---------------------------------------------------------------------------
-- Load
-- ---------------------------------------------------------------------------
section("Plugin")

local cs_ok, cs = pcall(require, "claude-status")
ok("claude-status loads without error", cs_ok, not cs_ok and tostring(cs))

local sess_ok, sessions = pcall(require, "claude-status.sessions")
ok("claude-status.sessions loads without error", sess_ok, not sess_ok and tostring(sessions))

if not cs_ok or not sess_ok then
  io.write("\nFatal: module load failed — aborting\n")
  vim.cmd("cquit 1")
end

ok("register is a function",              type(cs.register)              == "function")
ok("unregister is a function",            type(cs.unregister)            == "function")
ok("statusline is a function",            type(cs.statusline)            == "function")
ok("bell is a function",                  type(cs.bell)                  == "function")
ok("_update_nvim_active is a function",   type(cs._update_nvim_active)   == "function")

-- ---------------------------------------------------------------------------
-- Highlight groups
-- Headless Neovim loads no colorscheme so Normal.bg is nil, but our plugin
-- sets fg colours unconditionally — those should always be non-zero.
-- ---------------------------------------------------------------------------
section("Highlight groups")

for _, token in ipairs({ "Working", "Ready", "Dim", "Warning", "Error" }) do
  local hl = vim.api.nvim_get_hl(0, { name = "ClaudeStatus" .. token })
  ok("ClaudeStatus" .. token .. " has fg colour", (hl.fg or 0) > 0)
end

-- ---------------------------------------------------------------------------
-- Sessions API
-- ---------------------------------------------------------------------------
section("Sessions")

local SID   = "test-abc123"
local BUFNR = 999  -- fake; never needs to exist as a real Neovim buffer

sessions._buf_sessions[BUFNR] = SID
ok("get_session returns session for registered buf",   sessions.get_session(BUFNR) == SID)
ok("get_bufnr returns bufnr for registered session",   sessions.get_bufnr(SID) == BUFNR)
ok("get_session returns nil for unknown buf",           sessions.get_session(11111) == nil)
ok("get_bufnr returns nil for unknown session",         sessions.get_bufnr("no-such") == nil)

sessions.unregister(SID)
ok("get_session nil after unregister",   sessions.get_session(BUFNR) == nil)
ok("get_bufnr nil after unregister",     sessions.get_bufnr(SID)    == nil)

sessions._buf_sessions[BUFNR] = SID
sessions.on_buf_delete(BUFNR)
ok("get_session nil after on_buf_delete", sessions.get_session(BUFNR) == nil)

-- ---------------------------------------------------------------------------
-- Statusline
-- ---------------------------------------------------------------------------
section("Statusline")

-- No session registered for the current buf → must return ""
ok("returns '' with no session for current buf", cs.statusline() == "")

-- Inject the session for the headless buffer (buf 1, the default scratch buf).
-- In headless mode vim.fn.mode() returns 'n', so mode_chr = 'N' and the
-- highlight group is ClaudeStatusDim.
local cur_buf = vim.api.nvim_win_get_buf(0)
sessions._buf_sessions[cur_buf] = SID

local stl = cs.statusline()
ok("non-empty when session is registered",        stl ~= "")
ok("contains %#ClaudeStatus highlight escape",    stl:find("%%#ClaudeStatus") ~= nil)
ok("contains mode character N (normal in headless)", stl:find(" N") ~= nil)

sessions._buf_sessions[cur_buf] = nil

-- ---------------------------------------------------------------------------
-- Bell
-- ---------------------------------------------------------------------------
section("Bell")

vim.o.visualbell = true
ok("returns '' when visualbell is set", cs.bell() == "")
vim.o.visualbell = false

vim.o.belloff = "all"
ok("returns '' when belloff=all", cs.bell() == "")
vim.o.belloff = ""

-- ---------------------------------------------------------------------------
-- nvim_active tracking
--
-- Write a state file for a fake session, inject that session as the current
-- headless buffer, call _update_nvim_active(), then read the file back to
-- confirm nvim_active was patched to true.
-- ---------------------------------------------------------------------------
section("nvim_active tracking")

local NA_SID   = "test-nvim-active-xyz"
local na_path  = "/tmp/claude-status-" .. NA_SID .. ".json"

-- Write initial state with nvim_active = false
local wf = io.open(na_path, "w")
wf:write('{"session_id":"' .. NA_SID .. '","state":"ready","nvim_active":false}\n')
wf:close()

-- Inject the session for the current headless buffer so _update_nvim_active
-- will see it as the focused buffer and patch nvim_active → true
sessions._buf_sessions[cur_buf] = NA_SID
cs._update_nvim_active()
sessions._buf_sessions[cur_buf] = nil

local rf = io.open(na_path, "r")
ok("state file still exists after patch", rf ~= nil)
if rf then
  local content = rf:read("*a")
  rf:close()
  local j_ok, state = pcall(vim.fn.json_decode, content)
  ok("state file is valid JSON after patch",       j_ok and type(state) == "table")
  ok("nvim_active patched to true for active buf", j_ok and state.nvim_active == true)
end
os.remove(na_path)

-- Verify nvim_active is set to false for a non-current buffer
local na2_path = "/tmp/claude-status-test-nvim-inactive.json"
local wf2 = io.open(na2_path, "w")
wf2:write('{"session_id":"test-nvim-inactive","state":"ready","nvim_active":true}\n')
wf2:close()

sessions._buf_sessions[BUFNR] = "test-nvim-inactive"  -- fake buf, not current
cs._update_nvim_active()
sessions._buf_sessions[BUFNR] = nil

local rf2 = io.open(na2_path, "r")
if rf2 then
  local content2 = rf2:read("*a")
  rf2:close()
  local j2_ok, state2 = pcall(vim.fn.json_decode, content2)
  ok("nvim_active patched to false for inactive buf", j2_ok and state2.nvim_active == false)
end
os.remove(na2_path)

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
io.write(string.format("\n%d passed, %d failed\n\n", PASS, FAIL))
if FAIL > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
