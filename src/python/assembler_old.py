import argparse
import copy
import struct
import functools
from lark import Lark, Transformer

class Expr:
	def __init__(self, values, operators):
		self.values = values
		self.operators = operators

	def get_size(self):
		return 2

	def evaluate(self, namespace):
		value = evaluate(self.values[0], namespace)
		for operator, value2 in zip(self.operators, self.values[1:]):
			value2 = evaluate(value2, namespace)
			if operator == "+":
				value += value2
			else:
				value -= value2
		return value

	def compile(self, namespace, offset):
		return [self.evaluate(namespace)]

class LabelDef:
	def __init__(self, name):
		self.name = name

	def get_size(self):
		return 0

	def compile(self, namespace, offset):
		return []

class Macro:
	def __init__(self, name, items):
		self.name = name
		self.items = items
		self.namespace = {}

	def build_namespace(self, namespace):
		definition = namespace.get(self.name, None)
		assert isinstance(definition, MacroDef), f"undefined macro {self.name}"
		self.definition = definition

		self.namespace = copy.copy(namespace)
		self.namespace.update(definition.namespace)

		label_defs = list(filter(lambda x: isinstance(x, LabelDef), definition.program))
		for label_def in label_defs:
			self.namespace[label_def.name] = 0

		signature = namespace[self.name].macro.items
		assert len(signature) == len(self.items), "incorrect number of arguments"

		for name, item in zip(signature, self.items):
			if isinstance(name, str):
				assert not isinstance(item, Macro), "unexpected macro"
				self.namespace[name] = evaluate(item, namespace)
			else:
				assert isinstance(item, Macro), f"expected macro, got {item.__cls__.__name__}"
				self.namespace[name.name] = namespace[item.name].partial(item.items, namespace)

		macros = list(filter(lambda x: isinstance(x, Macro), self.definition.program))
		for macro in macros:
			macro.build_namespace(self.namespace)

	def get_size(self):
		return get_program_size(self.definition.program, self.namespace)

	def get_label_positions(self):
		return get_label_positions(self.definition.program, self.namespace)

	def compile(self, namespace, offset):
		labels = dict(map(lambda x: [x[0], x[1] + offset], self.get_label_positions()))
		self.namespace.update(labels)

		macros = list(filter(lambda x: isinstance(x, Macro), self.definition.program))
		for macro in macros:
			macro.build_namespace(self.namespace)

		return compile(self.definition.program, self.namespace)

class MacroDef:
	def __init__(self, macro, program):
		self.macro = macro
		self.program = program
		self.namespace = {}

		label_defs = list(filter(lambda x: isinstance(x, LabelDef), program))
		for label_def in label_defs:
			self.namespace[label_def.name] = 0

	def partial(self, items, namespace):
		assert len(items) <= len(self.macro.items), "too many arguments to partial macro"
		new_macro = MacroDef(Macro(self.macro.name, self.macro.items[len(items):]), self.program)
		for name, item in zip(self.macro.items[:len(items)], items):
			if isinstance(name, str):
				assert not isinstance(item, Macro), "unexpected macro"
				new_macro.namespace[name] = evaluate(item, namespace)
			else:
				assert isinstance(item, Macro), f"expected macro, got {item.__cls__.__name__}"
				new_macro.namespace[name.name] = namespace[item.name].partial(item.items, namespace)

		return new_macro

	def get_size(self):
		return 0

	def compile(self, namespace, offset):
		return []

class SlqTransformer(Transformer):
	def program(self, items):
		return list(items)

	def num(self, items):
		return int(items[0])

	def name(self, items):
		return str(items[0])

	def expr(self, items):
		value = True
		values = []
		operators = []

		for i in items:
			if value:
				values.append(i)
			else:
				operators.append(str(i))

			value = not value

		return Expr(values, operators)

	def label_def(self, items):
		return LabelDef(str(items[0]))

	def macro(self, items):
		return Macro(items[0], items[1:])

	def macro_def(self, items):
		return MacroDef(*items)

def evaluate(item, namespace):
	if isinstance(item, str):
		assert not isinstance(namespace[item], MacroDef), "macros must be in square brackets"
		return namespace[item]
	if isinstance(item, int):
		return item

	return item.evaluate(namespace)

def get_size(item, namespace):
	if isinstance(item, int):
		return 2
	if isinstance(item, str):
		assert not isinstance(namespace[item], MacroDef), "macros must be in square brackets"
		return 2

	return item.get_size()

def get_program_size(program, namespace):
	size = 0
	for item in program:
		size += get_size(item, namespace)

	return size

def get_label_positions(program, namespace):
	for i, item in enumerate(program):
		if isinstance(item, LabelDef):
			yield (item.name, get_program_size(program[:i], namespace))

def compile(program, namespace):
	output = []

	for item in program:
		if isinstance(item, str) or isinstance(item, int):
			output.append(evaluate(item, namespace))
		else:
			output += item.compile(namespace, len(output) * 2)

	return output

if __name__ == "__main__":
	p = argparse.ArgumentParser(description="Assemble Subleq assembly language.")
	p.add_argument("file", help="an input assembly file")
	p.add_argument("-o", "--output", default="subleq.o",
		help="the output filename")

	args = p.parse_args()
	with open(args.file) as f:
		source = f.read()

	with open("metasubleq.lark") as f:
		grammar = f.read()

	l = Lark(grammar, parser="lalr", transformer=SlqTransformer())

	tree = l.parse(source)

	namespace = {}

	macro_defs = list(filter(lambda x: isinstance(x, MacroDef), tree))
	for macro_def in macro_defs:
		assert all(map(lambda x: isinstance(x, str) or (isinstance(x, Macro) and len(x.items) == 0),
			macro_def.macro.items)), "malformed macro signature"
		namespace[macro_def.macro.name] = macro_def

	label_defs = list(filter(lambda x: isinstance(x, LabelDef), tree))
	for label_def in label_defs:
		namespace[label_def.name] = 0

	macros = list(filter(lambda x: isinstance(x, Macro), tree))
	for macro in macros:
		macro.build_namespace(namespace)

	namespace.update(dict(get_label_positions(tree, namespace)))

	code = compile(tree, namespace)

	print(code)

	with open(args.output, "wb") as f:
		for data in map(functools.partial(struct.pack, ">h"), code):
			f.write(data)
