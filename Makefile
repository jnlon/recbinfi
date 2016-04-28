all:
	ocamlopt shorthands.mli
	ocamlopt -c shorthands.ml
	ocamlopt formats.mli
	ocamlopt -c formats.ml
	ocamlopt unix.cmxa shorthands.cmx formats.cmx main.ml -o recbinfi
clean: 
	rm shorthands.cmi shorthands.cmx shorthands.o formats.cmi formats.cmx formats.o main.cmi main.cmx main.o recbinfi
