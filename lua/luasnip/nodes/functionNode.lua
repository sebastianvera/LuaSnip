local Node = require("luasnip.nodes.node").Node
local FunctionNode = Node:new()
local util = require("luasnip.util.util")
local node_util = require("luasnip.nodes.util")
local types = require("luasnip.util.types")
local events = require("luasnip.util.events")
local tNode = require("luasnip.nodes.textNode")

local function F(fn, args, ...)
	return FunctionNode:new({
		fn = fn,
		args = node_util.wrap_args(args),
		type = types.functionNode,
		mark = nil,
		user_args = { ... },
	})
end

FunctionNode.input_enter = tNode.input_enter

function FunctionNode:get_static_text()
	-- static_text will already have been generated, if possible.
	-- If it isn't generated, prevent errors by just setting it to empty text.
	if not self.static_text then
		self.static_text = { "" }
	end
	return self.static_text
end

-- function-text will not stand out in any way in docstring.
FunctionNode.get_docstring = FunctionNode.get_static_text

function FunctionNode:update()
	local args = self:get_args()
	-- skip this update if
	-- - not all nodes are available.
	-- - the args haven't changed.
	if not args or vim.deep_equal(args, self.last_args) then
		return
	end
	self.last_args = args
	local text = util.wrap_value(
		self.fn(args, self.parent, unpack(self.user_args))
	)
	if vim.o.expandtab then
		util.expand_tabs(text, util.tab_width())
	end
	-- don't expand tabs in parent.indentstr, use it as-is.
	self.parent:set_text(self, util.indent(text, self.parent.indentstr))
end

local update_errorstring = [[
Error while evaluating functionNode@%d for snippet '%s':
%s
 
:h luasnip-docstring for more info]]
function FunctionNode:update_static()
	local args = self:get_static_args()
	-- skip this update if
	-- - not all nodes are available.
	-- - the args haven't changed.
	if not args or vim.deep_equal(args, self.last_args) then
		return
	end
	-- should be okay to set last_args even if `fn` potentially fails, future
	-- updates will fail aswell, if not the `fn` also doesn't always work
	-- correctly in normal expansion.
	self.last_args = args
	local ok, static_text = pcall(
		self.fn,
		args,
		self.parent,
		unpack(self.user_args)
	)
	if not ok then
		print(
			update_errorstring:format(
				self.indx,
				self.parent.snippet.name,
				static_text
			)
		)
		static_text = { "" }
	end
	self.static_text = util.wrap_value(static_text)
end

function FunctionNode:update_restore()
	-- only if args still match.
	if self.static_text and vim.deep_equal(self:get_args(), self.last_args) then
		self.parent:set_text(self, self.static_text)
	else
		self:update()
	end
end

-- FunctionNode's don't have static text, nop these.
function FunctionNode:put_initial(_)
	self.visible = true
end

function FunctionNode:indent(_) end

function FunctionNode:expand_tabs(_) end

function FunctionNode:make_args_absolute(position_so_far)
	self.args_absolute = {}
	node_util.make_args_absolute(self.args, position_so_far, self.args_absolute)
end

function FunctionNode:set_dependents()
	local dict = self.parent.snippet.dependents_dict
	local append_list = vim.list_extend(
		{ "dependents" },
		self.absolute_position
	)
	append_list[#append_list + 1] = "dependent"

	for _, arg in ipairs(self.args_absolute) do
		-- mutates arg! Contains key for dict and this node, from now on.
		dict:set(vim.list_extend(vim.deepcopy(arg), append_list), self)
	end
end

return {
	F = F,
	FunctionNode = FunctionNode,
}
