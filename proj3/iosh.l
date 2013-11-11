/* Scanner using flex*/
%{
#include <stdlib.h>
#include <string.h>
#include "globals.h"
#include "y.tab.h"
void yyerror(char *);
%}
delim [ \t]+
word ("!"|"@"|"$"|"%"|"^"|"*"|"("|")"|"-"|"_"|"+"|"="|"{"|"}"|"["|"]"|"\\"|"\'"|":"|";"|"\/"|"."|","|"~"|"`"|[a-zA-Z0-9])+
string \".*\"
comment "#".*"\n"
%%
{comment} {return COMMENT;}
"setprompt" {return SETPROMPT;}
"debug" {return DEBUG;}
"chdir" {return CHDIR;}
"quit" {return QUIT;}
"<" {return '<';}
">" {return '>';}
{string} {yylval.string_val = strdup(yytext);	
	return STRING;}
{word} {yylval.string_val = strdup(yytext);
	return WORD;}
"\n" {return NEWLINE;}
{delim} {}
%%
