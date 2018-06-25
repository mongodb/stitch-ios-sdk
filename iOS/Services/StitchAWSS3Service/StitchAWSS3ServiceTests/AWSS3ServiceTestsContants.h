#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)

#if defined(AWS_ACCESS_KEY_ID) && defined(AWS_SECRET_ACCESS_KEY)
#define __AWS_ACCESS_KEY_ID @ STRINGIZE2(AWS_ACCESS_KEY_ID)
#define __AWS_SECRET_ACCESS_KEY @ STRINGIZE2(AWS_SECRET_ACCESS_KEY)
#else
#define __AWS_ACCESS_KEY_ID NULL
#define __AWS_SECRET_ACCESS_KEY NULL
#endif

#import <Foundation/Foundation.h>

static NSString* __nullable const TEST_AWS_ACCESS_KEY_ID = __AWS_ACCESS_KEY_ID;
static NSString* __nullable const TEST_AWS_SECRET_ACCESS_KEY = __AWS_SECRET_ACCESS_KEY;
