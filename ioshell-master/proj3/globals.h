/************ global.h *********/
#include <stdbool.h>
/*global flags*/
bool debug_flag;

/*prompt string*/
char* prompt;

/* command types */
typedef enum eCommandType {QUITCMD, CHDIRCMD, EXECPROGCMD, SETPROMPTCMD, SETDEBUGCMD} eCommandType;
/* struct for tokens */
typedef struct command command;
typedef struct arglist arglist;
struct command{
	char* command;
	enum eCommandType commandType;
	char* inputFrom;
	char* outputTo;
	int argc;
	arglist* argStart;	
};

struct arglist{
	char* arg;
	arglist* next;
};

