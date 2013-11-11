COMPILER = gcc 
CCFLAGS = -g -Wall 
YACC = bison
LEX = flex
YYFLAGS = -y -d
LEXFLAGS = -I
all: iosh

y.tab.o lex.yy.o: y.tab.c lex.yy.c
	$(COMPILER) $(CCFLAGS) -c y.tab.c lex.yy.c

iosh: y.tab.o lex.yy.o
	$(COMPILER) $(CCFLAGS) y.tab.o lex.yy.o -lfl -o iosh

y.tab.c y.tab.h: iosh.y
	$(YACC) $(YYFLAGS) iosh.y

lex.yy.c: iosh.l
	$(LEX) $(LEXFLAGS) iosh.l

clean:
	rm -rf iosh lex.yy.c lex.yy.o y.tab.c y.tab.h y.tab.o 
