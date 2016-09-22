#import "Settings.h"
#import "DownloadManager.h"

@interface DownloadManager ()
@property NSURLSession *session;
@property NSURLSessionDownloadTask *downloadTask;
@property NSURL *url;
@property NSURL *savePath;
@property NSData *resumeData;
@property Settings *settings;
@end

@implementation DownloadManager

- (instancetype)initWithURL:(NSURL *)url savePath:(NSURL *)path{
  self = [super init];
  if (self) {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    _url = url;
    _savePath = path;
    _settings = [[Settings alloc] init];
  }
  return self;
}

- (void)startDownload {
  NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
  self.downloadTask = [self.session downloadTaskWithRequest:request];
  NSLog(@"Download started.");
  [self.downloadTask resume];
}

- (void)pauseDownload {
  [self.downloadTask cancelByProducingResumeData:^(NSData *resumeData) {
    NSLog(@"Download paused...");
    if (!resumeData) return;
    NSLog(@"...and can be resumed.");
    self.resumeData = resumeData;
    self.downloadTask = nil;
  }];
}

- (void)resumeDownload {
  NSLog(@"Download resumed...");
  if (!self.resumeData) {
    NSLog(@"...from scratch.");
    [self startDownload];
    return;
  }
  NSLog(@"...from where it left off.");
  self.downloadTask = [self.session downloadTaskWithResumeData:self.resumeData];
  [self.downloadTask resume];
}

# pragma mark NSURLSessionDownloadDelegate Methods

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  self.totalBytes = totalBytesExpectedToWrite;
  self.bytesWritten = totalBytesWritten;
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
  NSLog(@"Download finished.");
  [[NSFileManager defaultManager] copyItemAtURL:location toURL:self.savePath error:nil];
  self.downloadComplete = YES;
  [self.session invalidateAndCancel];
}

- (void)URLSession:(NSURLSession *)session
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition,
                                  NSURLCredential *))completionHandler {

  if ([challenge.protectionSpace.authenticationMethod
      isEqualToString:NSURLAuthenticationMethodServerTrust]) {
    
    if ([[self.settings.kJDS allValues] containsObject:challenge.protectionSpace.host] ||
        [challenge.protectionSpace.host isEqualToString:self.settings.kJDSExternalHost]) {
      NSURLCredential *credential =
          [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
      completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    
    } else {
      completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
  } else {
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
  }
}

# pragma mark NSURLSessionTaskDelegate Methods

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
  if (error || ((NSHTTPURLResponse *)task.response).statusCode >= 400) {
    NSLog(@"Error: %@\nResponse: %@", error, task.response);
    
    if (error.code == NSURLErrorCancelled &&
        ((NSHTTPURLResponse *)task.response).statusCode < 400) {
      return;
    }
    
    if (![task.originalRequest.URL.host isEqualToString:self.settings.kJDSExternalHost]) {
      NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
      self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
      NSURLComponents *newURL = [NSURLComponents componentsWithURL:task.originalRequest.URL
                                           resolvingAgainstBaseURL:NO];
      newURL.host = self.settings.kJDSExternalHost;
      self.url = newURL.URL;
      [self startDownload];
    } else {
      NSAlert *alert = [[NSAlert alloc] init];
      alert.messageText = @"Error: Unable to download upgrade package.";
      alert.informativeText = @"Please check your connection and re-open this applicationt to try again.";
      [alert performSelectorOnMainThread:@selector(runModal) withObject:NULL waitUntilDone:YES];
      [NSApp terminate:self];
    }
  }
}

@end
