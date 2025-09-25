//
//  FTS5SimpleTokenizer.m
//  FTS5SimpleTokenizer
//
//  Created by Jaymin on 2024/3/29.
//

#import "FTS5SimpleTokenizer.h"
#import <SQLCipher/sqlite3.h>

#ifdef __cplusplus
extern "C" {
#endif

void sqlite3_simple_init(sqlite3 *db, char **pzErrMsg, const sqlite3_api_routines *pApi);

#ifdef __cplusplus
}
#endif

@implementation FTS5SimpleTokenizer

+ (void)registerTokenizer {
    int rc = sqlite3_auto_extension((void (*)(void))sqlite3_simple_init);
}

@end
