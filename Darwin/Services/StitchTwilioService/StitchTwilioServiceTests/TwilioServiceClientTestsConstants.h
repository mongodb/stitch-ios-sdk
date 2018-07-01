#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)

#if defined(TWILIO_SID) && defined(TWILIO_AUTH_TOKEN)
#define __TWILIO_SID @ STRINGIZE2(TWILIO_SID)
#define __TWILIO_AUTH_TOKEN @ STRINGIZE2(TWILIO_AUTH_TOKEN)
#else
#define __TWILIO_SID NULL
#define __TWILIO_AUTH_TOKEN NULL
#endif

#import <Foundation/Foundation.h>

static NSString* __nullable const TEST_TWILIO_SID = __TWILIO_SID;
static NSString* __nullable const TEST_TWILIO_AUTH_TOKEN = __TWILIO_AUTH_TOKEN;
