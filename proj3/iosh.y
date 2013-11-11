%{/* bison parser for iosh */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <errno.h>
#include <fcntl.h>
#include "globals.h"
#include "y.tab.h"

extern int errno;

command* addArg(char* arg, command* curCmd);
command* newCommand(void);
command* setPromptCmd(command* curCmd);
command* setDebugCmd(command* curCmd);
command* quitCmd();
command* chdirCmd(command* curCmd);
command* setIOFiles(char* inFile, command* curCmd, char* outFile);
command* setProg(char* progName, command* curCmd);

void run(command* curCmd);
void runProg(command* curCmd);

int yylex(void);
void yyerror(char* s);
void chdirError(char* directory);
void execError(char* commandName);
%}

%union{
	char* string_val;
	command* command_val;
};
%start shell

%token <string_val> WORD
%token <string_val> STRING
%token NEWLINE
%token COMMENT
%token SETPROMPT
%token DEBUG
%token CHDIR
%token QUIT
%token '<'
%token '>'

%type <command_val> builtin 
%type <command_val> args
%type <command_val> command
%type <command_val> prog
%type <string_val> infile
%type <string_val> outfile

%%
shell:	  shell builtin NEWLINE {run($2); printf("%s%s%% ",prompt,dir);}
		| shell COMMENT {printf("%s%s%% ",prompt,dir);}
		| shell command NEWLINE {run($2); printf("%s%s%% ",prompt,dir);}
		|
		;

command: infile '<' prog outfile {$$ = setIOFiles($1, $3, $4);}
		 | prog outfile {$$ = setIOFiles("", $1, $2);}
		 ;

infile: WORD {$$ = $1;}
		;

outfile: '>' WORD {$$ = $2;}
		|{$$ = "";}
		;

prog:    WORD args {$$= setProg($1, $2);}

builtin: 	SETPROMPT args {$$ = setPromptCmd($2);}
		| DEBUG args {$$ = setDebugCmd($2);}
		| CHDIR args {$$ = chdirCmd($2);}
		| QUIT {$$ = quitCmd();}
		;
args:		args WORD {$$ = addArg($2, $1);}
		| args STRING {$$ = addArg($2, $1);}
		| {$$ = newCommand();}
		;
%%
void run(command* curCmd){
	switch(curCmd -> commandType){
		case SETPROMPTCMD:
			free(prompt);
			prompt = strdup(curCmd->argStart->arg);
			break;
		case QUITCMD:
			printf("quitting shell\n");
			exit(0);
			break;
		case CHDIRCMD:
			{
			int chdirErr = chdir(curCmd->argStart->arg);	
			if(chdirErr == -1){
				chdirError(curCmd->argStart->arg);			
			}
			else{
				getcwd(dir, sizeof(dir));
			}
			}
			break;
		case SETDEBUGCMD:
			if(strcmp("on", curCmd->argStart->arg)==0){
				debug_flag = true;
				printf("debug turned on\n");
			}
			else{
				debug_flag = false;
				printf("debug turned off\n");
			} 
			break;
		case EXECPROGCMD:
			runProg(curCmd);
			break;
	}
}

void runProg(command* curCmd){
	/*printf("Command: %s\n", curCmd->command);
	if(curCmd->inputFrom != NULL)
		printf("InFile: %s\n", curCmd->inputFrom);
	if(curCmd->outputTo != NULL)
		printf("OutFile: %s\n", curCmd->outputTo);
	arglist* argPtr2 = curCmd->argStart;
	while(argPtr2!= NULL){
		printf("args: %s\n", argPtr2->arg);
		argPtr2 = argPtr2->next;
	}*/
	/*build argument list */
	char** argsToPass = (char **)malloc(sizeof(char *)*(curCmd->argc+1));
	argsToPass[0] = strdup(curCmd->command);
	int i;
	arglist* argPtr = curCmd->argStart;
	for(i=1; i<= curCmd->argc; i++){
		argsToPass[i] = strdup(argPtr->arg);
		argPtr = argPtr->next;
		printf("arg %d %s\n", i, argsToPass[i]);
	}

	/* Fork and Exec below here */
	int pid;
	if((pid = fork()) != 0){
		/*parent process*/
		int status;
		waitpid(pid, &status, 0);
		/*status can be checked here to see what happened to child*/
	}
	else{
		/*child process*/
		/*dup any IO file redirects*/
		if(curCmd->inputFrom != NULL){
			int iFD;
			iFD = open(curCmd->inputFrom, O_RDONLY);
			if(iFD == -1){
				printf("Cannot open %s for input, will use STDIN instead.\n", curCmd->inputFrom);
			}
			else{
				dup2(iFD, STDIN_FILENO);
			}
		}
		if(curCmd->outputTo != NULL){
			int oFD;
			oFD = open(curCmd->outputTo, O_WRONLY | O_CREAT | O_TRUNC, S_IRWXU);
			if(oFD == -1){
				printf("Cannot output to %s, will use STDOUT instead.\n", curCmd->outputTo);
			}
			else{
				dup2(oFD, STDOUT_FILENO);
			}
		}
			execvp(argsToPass[0], argsToPass);
			/* execv should not return, something happened if the process gets here*/
			execError(argsToPass[0]);
			exit(1);
	}
}

command* newCommand(){
	command* newCommand = malloc(sizeof(command));
	newCommand->command = NULL;
	newCommand->commandType = 0;
	newCommand->inputFrom = NULL;
	newCommand->outputTo = NULL;
	newCommand->argStart = NULL;
	newCommand->argc = 0;
	return newCommand;
}

command* addArg(char* arg, command* curCmd){
	arglist* argPtr;
	if(curCmd->argc == 0){
		argPtr = malloc(sizeof(arglist));
		char* newArg = strdup(arg);
		argPtr->arg = newArg;
		argPtr->next = NULL;
		curCmd->argStart=argPtr;
		curCmd->argc=1;				
	}
	else{	
		argPtr = curCmd->argStart;
		while(argPtr->next != NULL){
			argPtr = argPtr->next;
		}
		arglist* newArgList = malloc(sizeof(arglist));
		char* newArg = strdup(arg);
		newArgList->arg = newArg;
		newArgList->next = NULL;
		argPtr->next = newArgList;
		curCmd->argc++;
	}	

	return curCmd;	
}

command* setIOFiles(char* inFile, command* curCmd, char* outFile){
	if(strcmp(inFile, "") != 0){
		curCmd->inputFrom = strdup(inFile);
	}
	if(strcmp(outFile, "") != 0){
		curCmd->outputTo = strdup(outFile);
	}
	return curCmd;
}

command* setProg(char* progName, command* curCmd){
	curCmd->command = strdup(progName);
	curCmd->commandType = EXECPROGCMD;
	return curCmd;
}

command* setPromptCmd(command* curCmd){
	curCmd->commandType = SETPROMPTCMD;
	return curCmd;
}

command* setDebugCmd(command* curCmd){
	curCmd->commandType = SETDEBUGCMD;
	return curCmd;
}

command* chdirCmd(command* curCmd){
	curCmd->commandType = CHDIRCMD;
	return curCmd;
}

command* quitCmd(){
	command* quitCommand = malloc(sizeof(command));
	quitCommand->command = NULL;
	quitCommand->commandType = QUITCMD;
	quitCommand->inputFrom = NULL;
	quitCommand->outputTo = NULL;
	quitCommand->argStart = NULL;
	quitCommand->argc = 0;
	return quitCommand;
}

int main(void){
	prompt = strdup("iosh");
	getcwd(dir, sizeof(dir));
	printf("%s%s%% ",prompt,dir);	
	yyparse();
	free(prompt);
	return 0;
}
	
void yyerror(char* s)
{
        printf("%s\n",s);
        printf("%s%s%% ",prompt,dir);
        yyparse();
        return;
}

void chdirError(char* directory){
	if(errno == EACCES)
		printf("You do not have permission to access directory: %s\n", directory);
	else if (errno == ENOENT)                                                
		printf("No such file or directory: %s\n", directory);
	else if (errno == ENOTDIR)
		printf("%s is not a directory\n", directory);
	else if (errno == EIO)
		printf("Input/Output error\n");
	else if (errno == ENOMEM)
		printf("Insufficient kernel memory was available\n");
	else
		printf("Change directory error\n");
}

void execError(char* commandName){
    /*check for other errors here*/
    printf("Cannot find or execute the specified command %s\n",commandName);
}
