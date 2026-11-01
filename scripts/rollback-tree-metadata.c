/* Read-only bounded Btrfs containment/identity query. No filesystem mutations. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/btrfs.h>
#include <linux/btrfs_tree.h>
#include <linux/openat2.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <sys/stat.h>
#include <unistd.h>
#define MAX_LEAVES 16
#define SEARCH_BYTES 32768
struct leaf { uint64_t id; char path[1024]; struct btrfs_ioctl_get_subvol_info_args info; };
static void fail(const char *why) { fprintf(stderr,"rollback-tree: %s: %s\n",why,strerror(errno)); exit(1); }
static void require(int ok,const char *why) { if(!ok){errno=EINVAL;fail(why);} }
static int search(int fd,uint64_t object,unsigned type,unsigned char *out) {
 struct btrfs_ioctl_search_args_v2 *a=calloc(1,sizeof(*a)+SEARCH_BYTES);if(!a)fail("allocation");
 a->key.tree_id=BTRFS_ROOT_TREE_OBJECTID;a->key.min_objectid=a->key.max_objectid=object;
 a->key.max_offset=UINT64_MAX;a->key.max_transid=UINT64_MAX;
 a->key.min_type=a->key.max_type=type;a->key.nr_items=MAX_LEAVES+1;a->buf_size=SEARCH_BYTES;
 if(ioctl(fd,BTRFS_IOC_TREE_SEARCH_V2,a))fail("root metadata search");
 require(a->key.nr_items<=MAX_LEAVES,"metadata count bound");
 memcpy(out,a->buf,SEARCH_BYTES);int n=a->key.nr_items;free(a);return n;
}
static void quota_off(int fd) {
 struct btrfs_ioctl_feature_flags f={0};unsigned char b[SEARCH_BYTES];
 if(ioctl(fd,BTRFS_IOC_GET_FEATURES,&f))fail("feature query");
 require(!(f.incompat_flags&BTRFS_FEATURE_INCOMPAT_SIMPLE_QUOTA),"simple quotas unsupported");
 require(search(fd,BTRFS_QUOTA_TREE_OBJECTID,BTRFS_ROOT_ITEM_KEY,b)==0,"quotas unsupported");
}
static struct btrfs_ioctl_get_subvol_info_args info(int fd) {
 struct btrfs_ioctl_get_subvol_info_args i={0};if(ioctl(fd,BTRFS_IOC_GET_SUBVOL_INFO,&i))fail("subvolume identity");return i;
}
static void uuid(const unsigned char *p,char *out) {
 snprintf(out,37,"%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",p[0],p[1],p[2],p[3],p[4],p[5],p[6],p[7],p[8],p[9],p[10],p[11],p[12],p[13],p[14],p[15]);
}
static void safe_path(const char *p) {
 require(*p && *p!='/' && strlen(p)<1024,"unsupported child path");
 const char *start=p;
 for(const char *q=p;;q++) {
  unsigned char c=*q;require(!c || (c>=32 && c<=126 && c!='|' && c!='\\'),"unsupported child path bytes");
  if(c=='/' || !c) {size_t n=q-start;require(n && !(n==1 && *start=='.') && !(n==2 && start[0]=='.' && start[1]=='.'),"child traversal component");start=q+1;}
  if(!c)break;
 }
}
static int cmp(const void *a,const void *b){return strcmp(((const struct leaf*)a)->path,((const struct leaf*)b)->path);}
int main(int argc,char **argv) {
 require(argc==2,"one source directory required");
 int fd=open(argv[1],O_RDONLY|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW);if(fd<0)fail("source open");
 struct stat st;if(fstat(fd,&st))fail("source inode");require(st.st_ino==BTRFS_FIRST_FREE_OBJECTID,"source is not a subvolume root");
 struct btrfs_ioctl_fs_info_args fs={0};if(ioctl(fd,BTRFS_IOC_FS_INFO,&fs))fail("filesystem identity");
 quota_off(fd);struct btrfs_ioctl_get_subvol_info_args root=info(fd);
 require(!(root.flags & ~BTRFS_ROOT_SUBVOL_RDONLY),"unsupported root flags");
 struct leaf leaves[MAX_LEAVES]={0};unsigned char refs[SEARCH_BYTES],verify[SEARCH_BYTES];
 int count=search(fd,root.treeid,BTRFS_ROOT_REF_KEY,refs);size_t offset=0;
 for(int n=0;n<count;n++) {
  require(offset+sizeof(struct btrfs_ioctl_search_header)<=SEARCH_BYTES,"reference header bound");
  struct btrfs_ioctl_search_header h;memcpy(&h,refs+offset,sizeof(h));offset+=sizeof(h);
  require(h.objectid==root.treeid && h.type==BTRFS_ROOT_REF_KEY && h.len>=sizeof(struct btrfs_root_ref) && h.len<=SEARCH_BYTES-offset,"reference shape");
  struct btrfs_root_ref r;memcpy(&r,refs+offset,sizeof(r));
  unsigned len=le16toh(r.name_len);require(len && len<=255 && sizeof(r)+len==h.len,"reference name bound");
  struct btrfs_ioctl_ino_lookup_args lookup={.treeid=root.treeid,.objectid=le64toh(r.dirid)};
  if(ioctl(fd,BTRFS_IOC_INO_LOOKUP,&lookup))fail("parent path lookup");
  size_t parent_len=strnlen(lookup.name,sizeof(lookup.name));require(parent_len<sizeof(lookup.name) && parent_len+len<sizeof(leaves[n].path),"path bound");
  memcpy(leaves[n].path,lookup.name,parent_len);memcpy(leaves[n].path+parent_len,refs+offset+sizeof(r),len);leaves[n].path[parent_len+len]=0;
  safe_path(leaves[n].path);leaves[n].id=h.offset;
  struct open_how how={.flags=O_RDONLY|O_DIRECTORY|O_CLOEXEC,.resolve=RESOLVE_BENEATH|RESOLVE_NO_SYMLINKS};
  int child=syscall(SYS_openat2,fd,leaves[n].path,&how,sizeof(how));if(child<0)fail("contained child open");
  leaves[n].info=info(child);require(!(leaves[n].info.flags & ~BTRFS_ROOT_SUBVOL_RDONLY),"unsupported child flags");require(leaves[n].info.treeid==h.offset,"child containment identity");
  struct btrfs_ioctl_fs_info_args cf={0};if(ioctl(child,BTRFS_IOC_FS_INFO,&cf))fail("child filesystem identity");
  require(!memcmp(cf.fsid,fs.fsid,16),"foreign child filesystem");close(child);
  require(search(fd,h.offset,BTRFS_ROOT_REF_KEY,verify)==0,"deeper subvolume nesting unsupported");
  offset+=h.len;
 }
 // Requery the complete direct-reference set. No output on error or truncation.
 require(search(fd,root.treeid,BTRFS_ROOT_REF_KEY,verify)==count && !memcmp(refs,verify,offset),"topology changed during enumeration");
 for(int n=0;n<count;n++) {
  struct open_how how={.flags=O_RDONLY|O_DIRECTORY|O_CLOEXEC,.resolve=RESOLVE_BENEATH|RESOLVE_NO_SYMLINKS};
  int child=syscall(SYS_openat2,fd,leaves[n].path,&how,sizeof(how));if(child<0)fail("child revalidation open");
  struct btrfs_ioctl_get_subvol_info_args current=info(child);
  struct btrfs_ioctl_fs_info_args cf={0};if(ioctl(child,BTRFS_IOC_FS_INFO,&cf))fail("child filesystem revalidation");
  require(!memcmp(cf.fsid,fs.fsid,16) && current.treeid==leaves[n].id && !memcmp(current.uuid,leaves[n].info.uuid,16) && !memcmp(current.parent_uuid,leaves[n].info.parent_uuid,16) && current.flags==leaves[n].info.flags,"child identity/flags changed");close(child);
 }
 struct btrfs_ioctl_get_subvol_info_args after=info(fd);require(after.treeid==root.treeid && !memcmp(after.uuid,root.uuid,16) && after.flags==root.flags,"source identity/flags changed");quota_off(fd);
 qsort(leaves,count,sizeof(*leaves),cmp);
 for(int n=1;n<count;n++)require(strcmp(leaves[n-1].path,leaves[n].path),"duplicate containment path");
 char fsid[37],id[37],parent[37];uuid(fs.fsid,fsid);uuid(root.uuid,id);uuid(root.parent_uuid,parent);
 printf("TREE|%s|%s|%s|%u\n",fsid,id,parent,(unsigned)!!(root.flags&BTRFS_ROOT_SUBVOL_RDONLY));
 for(int n=0;n<count;n++){uuid(leaves[n].info.uuid,id);uuid(leaves[n].info.parent_uuid,parent);printf("LEAF|%s|%s|%s|%u\n",leaves[n].path,id,parent,(unsigned)!!(leaves[n].info.flags&BTRFS_ROOT_SUBVOL_RDONLY));}
 close(fd);return 0;
}
