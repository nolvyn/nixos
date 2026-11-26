/* Publish bounded immutable metadata without persistent temporary names. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
static void fail(const char *why) { fprintf(stderr,"rollback-record: %s: %s\n",why,strerror(errno));exit(1); }
int main(int argc,char **argv) {
 if(argc!=3 || strlen(argv[2])!=101){errno=EINVAL;fail("record basename shape");}
 for(unsigned n=0;n<101;n++) {
  int dash=n==8 || n==13 || n==18 || n==23 || n==36;
  if(dash ? argv[2][n]!='-' : !((argv[2][n]>='0' && argv[2][n]<='9') || (argv[2][n]>='a' && argv[2][n]<='f'))){errno=EINVAL;fail("record basename bytes");}
 }
 unsigned char data[20001];size_t size=fread(data,1,sizeof(data),stdin);
 if(ferror(stdin) || !feof(stdin) || !size || size>20000){errno=EINVAL;fail("metadata input bound");}
 int directory=open(argv[1],O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);if(directory<0)fail("metadata directory open");
 int record=openat(directory,".",O_TMPFILE|O_RDWR|O_CLOEXEC,0600);if(record<0)fail("unnamed record create");
 for(size_t done=0;done<size;){ssize_t n=write(record,data+done,size-done);if(n<0 && errno==EINTR)continue;if(n<=0)fail("metadata write");done+=(size_t)n;}
 if(fsync(record))fail("record sync");
 if(linkat(record,"",directory,argv[2],AT_EMPTY_PATH))fail("no-overwrite record publication");
 if(fsync(directory))fail("directory sync");
 close(record);close(directory);return 0;
}
