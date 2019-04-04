#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)

#if defined(PERF_IOS_API_KEY)
#define __PERF_IOS_API_KEY @ STRINGIZE2(PERF_IOS_API_KEY)
#else
#define __PERF_IOS_API_KEY NULL
#endif

#import <Foundation/Foundation.h>

static NSString* __nullable const PERF_IOS_API_KEY = __PERF_IOS_API_KEY;
