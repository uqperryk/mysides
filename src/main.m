// portions (l) copyleft 2011 Adam Strzelecki nanoant.com
// sidebar modification commands added by github/mosen

// Some interesting IDs:
//   com.apple.LSSharedFileList.SpecialItemIdentifier
//   com.apple.LSSharedFileList.TemplateSystemSelector

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

extern CFTypeRef LSSharedFileListItemCopyAliasData(LSSharedFileListItemRef inItem);
extern int _IconRefIsTemplate(IconRef iconRef);

extern CFStringRef kLSSharedFileListSpecialItemIdentifier;
extern CFStringRef kLSSharedFileListItemTargetName;
extern CFStringRef kLSSharedFileListItemManaged;

// I am so smart, this symbol isn't exposed by LaunchServices framework, but I get it anyhow with help of "nm" ;)
#define kLSSharedFileListItemTemplateSystemSelector (CFStringRef)((char *)kLSSharedFileListItemTargetName + (3 * 0x40))
#define kLSSharedFileListItemClass (CFStringRef)((char *)kLSSharedFileListItemBeforeFirst + (3 * 0x40))

void print_help(char const *arg0)
{
    printf("Usage: %s list|add <name> <uri>|remove <name>\n", arg0);
    printf("\n");
    printf("\t list - list sidebar items\n");
    printf("\t add - append a sidebar item to the end of the list\n");
    //printf("\t\tinsert <name> <uri> [before]\t- insert a sidebar item at the start of the list, or before the given name\n");
    printf("\t remove - remove a sidebar item\n");
    printf("\n");
}

// Find shared file list item by its display name
// Not responsible for allocating or releasing the list reference.
id find_itemname(LSSharedFileListRef sflRef, NSString *name)
{
    UInt32 seed;
    NSArray *list = CFBridgingRelease(LSSharedFileListCopySnapshot(sflRef, &seed));
    
    for(NSObject *obj in list) {
        LSSharedFileListItemRef sflItemRef = (__bridge LSSharedFileListItemRef)obj;
        CFStringRef nameRef = LSSharedFileListItemCopyDisplayName(sflItemRef);
        if (CFStringCompare(nameRef, (__bridge CFStringRef)name, 0) == 0) {
            if (nameRef) CFRelease(nameRef);
            return (__bridge id)(sflItemRef);
        }
    if (nameRef) CFRelease(nameRef);
    }
    return nil;
}

// Append an item to the sidebar
// Return the new index of the item added.
int sidebar_add(NSString *name, NSURL *uri, id after)
{
    LSSharedFileListRef sflRef = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListFavoriteItems, NULL);
    LSSharedFileListInsertItemURL(sflRef, kLSSharedFileListItemLast, (__bridge CFStringRef)name, NULL, (__bridge CFURLRef)uri, NULL, NULL);
    CFRelease(sflRef);
    printf("Added sidebar item with name: %s\n", [name UTF8String]);
    return 0;
}

// Remove named item from the sidebar
int sidebar_remove(NSString *name, NSURL *uri)
{
    LSSharedFileListRef sflRef = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListFavoriteItems, NULL);
    UInt32 seed;
    // Grab list snapshot for enumeration
    NSArray *list = CFBridgingRelease(LSSharedFileListCopySnapshot(sflRef, &seed));
    
    if ([[name lowercaseString] isEqualToString: @"all"]) {
        LSSharedFileListRemoveAllItems(sflRef);
        CFRelease(sflRef);
        
        return 0;
    } else {
        printf("neq all\n");
        
        for(NSObject *obj in list)  {
            LSSharedFileListItemRef sflItemRef = (__bridge LSSharedFileListItemRef)obj;
            CFStringRef nameRef = LSSharedFileListItemCopyDisplayName(sflItemRef);
            CFURLRef urlRef = NULL;
            LSSharedFileListItemResolve(sflItemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, &urlRef, NULL);
            
            // Found item: remove
            if (CFStringCompare(nameRef, (__bridge CFStringRef)name, 0) == 0) {
                LSSharedFileListItemRemove(sflRef, sflItemRef);
                CFRelease(sflRef);
                printf("Removed sidebar item with name: %s\n", [(NSString *) CFBridgingRelease(nameRef) UTF8String]);
                return 0;
            }
            if (nameRef) CFRelease(nameRef);
        }
    }
    

    
    printf("Could not find sidebar item with display name: %s\n", [name UTF8String]);
    CFRelease(sflRef);
    return 1;
}

int sidebar_insert(NSString *name, NSURL *uri, id before)
{
    return 1;
}

void sidebar_list()
{
    LSSharedFileListRef sflRef = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListFavoriteItems, NULL);
    UInt32 seed;
    
    if(!sflRef) {
        printf("No list!");
        return;
    }
    
    // Grab list snapshot for enumeration
    NSArray *list = CFBridgingRelease(LSSharedFileListCopySnapshot(sflRef, &seed));
    
    for(NSObject *object in list) {
        LSSharedFileListItemRef sflItemRef = (__bridge LSSharedFileListItemRef)object;
        CFStringRef nameRef = LSSharedFileListItemCopyDisplayName(sflItemRef);
        CFURLRef urlRef = NULL;
        // LSSharedFileListItemResolve(sflItemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, &urlRef, NULL);
        urlRef = LSSharedFileListItemCopyResolvedURL(sflItemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, NULL);
        
        //if (!nameRef || !urlRef) break;
        
        printf("%s -> %s\n",
               [(NSString *) CFBridgingRelease(nameRef) UTF8String],
               [(NSString *) CFBridgingRelease(CFURLGetString(urlRef)) UTF8String]);
        if(urlRef)  CFRelease(urlRef);
    }
    
    CFRelease(sflRef);
}

// Ussage: sfltool add-item [-n <display name>] <list identifier> <URL>
int add_item(NSString *list_id, NSString *url, NSString *display_name)
{
    
    return 0;
}
 
/**
 * Get a list of Shared File Lists.
 * In OS X 10.11 the `sfltool` indicates whether each file list has been modernized or not. 
 * (I believe this has to do with whether they use the .sfl file format).
 */
//int list_info()
//{
//    
//    return 0;
//}

int main (int argc, char const *argv[])
{
    if(argc >= 2) {
        if (strcmp(argv[1], "list") == 0) {
            sidebar_list();
            return 0;
        }
        
        if (strcmp(argv[1], "add") == 0) {
            NSString *name = [NSString stringWithUTF8String:argv[2]];
            NSURL *uri = [NSURL URLWithString:[NSString stringWithUTF8String:argv[3]]];
            
            return sidebar_add(name, uri, nil);
        }
        
        if (strcmp(argv[1], "remove") == 0) {
            if (strlen(argv[2]) == 0) {
                printf("No name supplied to remove!\n");
                return 1;
            }
            
            NSString *name = [NSString stringWithUTF8String:argv[2]];
            NSURL *uri = [NSURL URLWithString:@"file:///"]; // temporary not used
            return sidebar_remove(name, uri);
            
        }
        
        
    } else {
        print_help(argv[0]);
        return 1;
    }
    
    return 0;
}
