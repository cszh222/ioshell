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

command* addArg(char* arg, command* curCmd, eArgType argType);
command* newCommand(void);
command* setPromptCmd(command* curCmd);
command* setDebugCmd(command* curCmd);
command* quitCmd();
command* chdirCmd(command* curCmd);
command* setIOFiles(char* inFile, command* curCmd, char* outFile);
command* setProg(char* progName, command* curCmd);

void run(command* curCmd);
void runProg(command* curCmd);
void freeCommand(command* curCmd);

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
%token ENDOFFILE
%token '<'
%token '>'

%type <command_val> builtin 
%type <command_val> args
%type <command_val> command
%type <command_val> prog
%type <command_val> endoffile
%type <string_val> infile
%type <string_val> outfile


%%
shell:	  shell builtin NEWLINE {run($2);freeCommand($2); 
			printf("%s%s%% ",prompt,dir);fflush(stdout);}
		| shell COMMENT {printf("%s%s%% ",prompt,dir); fflush(stdout);}
		| shell command NEWLINE {run($2); freeCommand($2); 
			printf("%s%s%% ",prompt,dir); fflush(stdout);}
		| shell endoffile {run($2);}
		|
		;
endoffile: ENDOFFILE {$$ = quitCmd();}
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
		;

args:		args WORD {$$ = addArg($2, $1, WORDARG);}
		| args STRING {$$ = addArg($2, $1, STRINGARG);}
		| {$$ = newCommand();}
		;

builtin: 	SETPROMPT args {$$ = setPromptCmd($2);}
		| DEBUG args {$$ = setDebugCmd($2);}
		| CHDIR args {$$ = chdirCmd($2);}
		| QUIT {$$ = quitCmd();}
		;

%%
void run(command* curCmd){
	switch(curCmd -> commandType){
		case SETPROMPTCMD:
			if(curCmd->argStart != NULL){
				if(debug_flag){
					printf("Token Type = word\t  Token = setprompt\t Usage = setprompt\n");
					printf("Token Type = string\t  Token = %s\t Usage = string\n", curCmd->argStart->arg);
					printf("Token Type = end-of-line  Token = EOL\t\t Usage = EOL\n");
				}
				if(curCmd->argStart->argType == STRINGARG){
					free(prompt);
					prompt = strdup(curCmd->argStart->arg);
				}
				else {
					yyerror("syntax error");
				}
			}
			else{
				yyerror("syntax error");
			}
			break;
		case QUITCMD:
			if(debug_flag){
				printf("Token Type = word\t  Token = quit\t Usage = quit\n");
				printf("Token Type = end-of-line  Token = EOL\t Usage = EOL\n");
			}
			printf("quitting shell\n");
			exit(0);
			break;
		case CHDIRCMD: {
			if(curCmd->argStart != NULL){
				if(debug_flag){
					printf("Token Type = word\t  Token = chdir\t Usage = chdir\n");
					printf("Token Type = word\t  Token = %s\t Usage = word\n", curCmd->argStart->arg);
					printf("Token Type = end-of-line  Token = EOL\t Usage = EOL\n");  

				}
				if(curCmd->argStart->argType == WORDARG){
					int chdirErr = chdir(curCmd->argStart->arg);	
					if(chdirErr == -1){
						chdirError(curCmd->argStart->arg);			
					}
					else{
						getcwd(dir, sizeof(dir));
					}
				}
				else {
					yyerror("syntax error");
				}				
			}
			else {
				yyerror("syntax error");
			}
			}
			break;
		case SETDEBUGCMD:
			if(curCmd->argStart!= NULL){
				if(curCmd->argStart->argType == WORDARG){
					if(strcmp("on", curCmd->argStart->arg)==0){
						debug_flag = true;
						printf("debug turned on\n");
					}
					else if(strcmp("off", curCmd->argStart->arg)==0){
						debug_flag = false;
						printf("debug turned off\n");
					}
					else{
						yyerror("syntax error");
					}
				}
				else{
					yyerror("syntax error");
				}
			}
			else {
				yyerror("syntax error");
			} 
			break;
		case EXECPROGCMD:
			{
			if(debug_flag){
				if(curCmd->inputFrom != NULL){
					printf("Token Type = word\t Token = %s \t Usage = input file\n", curCmd->inputFrom);
					printf("Token Type = meta-char\t Token = <\t Usage = metachar\n");
				}
				
				printf("Token Type = word\t Token = %s \t Usage = cmd\n", curCmd->command);
				arglist* argPtr2 = curCmd->argStart;
				int count = 1;
				while(argPtr2!=NULL){
					printf("Token type = word\t Token = %s\t Usage = arg %d\n", argPtr2->arg, count);
					argPtr2 = argPtr2->next;
					count++;
				}

				if(curCmd->outputTo != NULL){
					printf("Token Type = meta-char\t Token = >\t Usage = metachar\n");
					printf("Token Type = word\t Token = %s\t Usage = output file\n", curCmd->outputTo);
				}

			}
			runProg(curCmd);
			}
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
	char** argsToPass = (char **)malloc(sizeof(char *)*(curCmd->argc+2));
	/*set first argument to the program path/name*/
	argsToPass[0] = strdup(curCmd->command);
	int i;
	/*Add arguments for the program*/
	arglist* argPtr = curCmd->argStart;
	for(i=1; i<= curCmd->argc; i++){
		argsToPass[i] = strdup(argPtr->arg);
		argPtr = argPtr->next;
		/*printf("arg %d %s\n", i, argsToPass[i]);*/
	}
	/*Terminate argument array with NULL*/
	argsToPass[curCmd->argc+1] = NULL;

	/* Fork and Exec below here */
	int pid;
	if((pid = fork()) != 0){
		/*parent process*/
		int status;
		if(waitpid(pid, &status, 0) == -1)
		   printf("Error waiting on child to exit\n");
		/*status can be checked here to see what happened to child*/
		/*argsToPass needs to be freed*/
		for(i=0; i<=curCmd->argc; i++)
			free(argsToPass[i]);
		free(argsToPass);
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

void freeCommand(command* curCmd){
	/*deallocates memory used for command*/
	free(curCmd->command);
	if(curCmd->inputFrom != NULL)
		free(curCmd->inputFrom);
	if(curCmd->outputTo != NULL)
		free(curCmd->outputTo);
	arglist* argPtr;
	while(curCmd->argStart != NULL){
		argPtr = curCmd->argStart;
		curCmd->argStart = curCmd->argStart->next;
		free(argPtr->arg);
		free(argPtr);
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

command* addArg(char* arg, command* curCmd, eArgType argType){
	arglist* argPtr;
	if(curCmd->argc == 0){
		argPtr = malloc(sizeof(arglist));
		char* newArg = strdup(arg);
		argPtr->arg = newArg;
		argPtr->next = NULL;
		argPtr->argType = argType;
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
		newArgList->argType = argType;
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
        printf("If you are trying to use a built in command,\n please follow the proper syntax below.\n");
        printf("The shell has following builtin commands:\n");

        printf("- setprompt \"string\" - sets the prompt of shell to the value of string.\n");
        printf("  Default prompt is iosh.\n");
        
        printf("- chdir directory - changes the current working directory to directory.\n");
        
        printf("- debug on/off - turns debugging mode on/off respectively.\n"); 
        printf("  Debug mode will print out parsed tokens, their type,\n");
        printf("  and usage before the command is exectued.\n");
        
        printf("- quit - quit the shell.\n");

        printf("%s%s%% ",prompt,dir);
        fflush(stdout);
        yyparse();
        return;
}

void chdirError(char* directory){
	if(errno == EACCES)
		fprintf(stderr,"You do not have permission to access directory: %s\n", directory);
	else if (errno == ENOENT)                                                
		fprintf(stderr,"No such file or directory: %s\n", directory);
	else if (errno == ENOTDIR)
		fprintf(stderr,"%s is not a directory\n", directory);
	else if (errno == EIO)
		fprintf(stderr,"Input/Output error\n");
	else if (errno == ENOMEM)
		fprintf(stderr,"Insufficient kernel memory was available\n");
	else
		fprintf(stderr,"Change directory error\n");
}

void execError(char* commandName){
    /*check for other errors here*/
    if(errno == ENAMETOOLONG)
    	fprintf(stderr,"Path name for \"%s\" is too long\n", commandName);
    else if (errno == E2BIG)
    	fprintf(stderr,"Too many arguments\n");
    else if (errno == EACCES)
    	fprintf(stderr,"You do not have permission to run %s\n", commandName);
    else if (errno == EIO)
    	fprintf(stderr,"Input/Output error\n");
    else if (errno == ETXTBSY)
    	fprintf(stderr,"%s is open by one or more processes for writing\n", commandName);
    else if (errno == ENOMEM)
    	fprintf(stderr,"Not enough kernel memory to run %s\n", commandName);
    else
    	fprintf(stderr,"Cannot find or execute %s\n",commandName);
}
