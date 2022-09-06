#!/usr/bin/python3

import sys
import copy
import struct
import functools
from lark import Lark, Transformer

class MacroDef:
	def __init__(self, macro, data):
		self.macro = macro
		self.data = data
		self.namespace = {}
	
	def get_size(self):
		return 0

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
		definition = namespace.get(self.name)
		assert isinstance(definition, MacroDef), f"undefined macro {self.name}"
		self.definition = definition


class mslTransformer(Transformer):
	def program(self, items):
		return list(items)
		
	def subprog(self, items):
		return list(items)
	
	def num(self, items):
		return int(items[0])
	
	def wordsize(self, items):
		return wordsize
	
	def name(self, items):
		return str(items[0])
		
	def macro_def(self, items):
		return MacroDef(*items)
	
	def macro(self, items):
		return Macro(items[0], items[1:])


def main():
	namespace = {}
	
	macro_defs = list(filter(lambda x: isinstance(x, MacroDef), transformed))
	for macro_def in macro_defs:
		assert all(map(lambda x: isinstance(x, str) or (isinstance(x, Macro) and len(x.items) == 0),
			macro_def.macro.items)), "malformed macro signature"
		namespace[macro_def.macro.name] = macro_def
		
		print(macro_def.macro.name, "\n\t", macro_def.data, "\n")
		
	macros = list(filter(lambda x: isinstance(x, Macro), transformed))
	
	for macro in macros:
		macro.build_namespace(namespace)


def parse_argv():
	if len(sys.argv) < 2:
		print("""Usage: compile.py [options] file...
	
Options:
	-o <file> | --output
		Place the compiled program in <file>
	-w <size> | --wordsize
		Set the word size to compile to in bytes
		
Notes:
	If a flag is given multiple times, the last instance wins
	
	If multiple files are given as input, they are concatenated in the order
	given
		""")
		
		sys.exit(1)
	
	ofile = 'subleq.out'
	
	i = 1
	while i < len(sys.argv):
		if sys.argv[i] == "-o" or sys.argv[i] == "--output":
			ofile = sys.argv[i+1]
			i += 2
		elif sys.argv[i] == "-w" or sys.argv[i] == "--wordsize":
			wordsize = sys.argv[i + 1]
			i += 2
		else:
			ifiles.append(sys.argv[i])
			i += 1
				

if __name__ == "__main__":

	wordsize = 2
	ifiles = []
	source = ""
	
	
	parse_argv()

	for i, file in enumerate(ifiles):
		with open(file) as f:
			ifiles[i] = f.read()
	
	source = "\n".join(ifiles)

	with open("metasubleq.lark") as f:
		grammar = f.read()
	
	tree = Lark(grammar).parse(source)
	
	transformed = mslTransformer().transform(tree)
	
	main()
	
	print(tree.pretty())
	print("\n", transformed)