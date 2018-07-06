#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)

#if defined(FCM_SENDER_ID) && defined(FCM_API_KEY)
#define __FCM_SENDER_ID @ STRINGIZE2(FCM_SENDER_ID)
#define __FCM_API_KEY @ STRINGIZE2(FCM_API_KEY)
#else
#define __FCM_SENDER_ID NULL
#define __FCM_API_KEY NULL
#endif

#import <Foundation/Foundation.h>

static NSString* __nullable const TEST_FCM_SENDER_ID = __FCM_SENDER_ID;
static NSString* __nullable const TEST_FCM_API_KEY = __FCM_API_KEY;
