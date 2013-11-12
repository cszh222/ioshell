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
<<EOF>> {return ENDOFFILE;}
"<" {return '<';}
">" {return '>';}
{string} {char* newString = malloc((strlen(yytext)-1)*sizeof(char));
		  memcpy(newString, &yytext[1], strlen(yytext)-2);
		  newString[strlen(yytext)-2] = '\0';
		  yylval.string_val = newString;		  	
		  return STRING;}
{word} {yylval.string_val = strdup(yytext);
	return WORD;}
"\n" {return NEWLINE;}
{delim} {}
%%
