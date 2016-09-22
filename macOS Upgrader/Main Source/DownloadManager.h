@import Cocoa;

@interface DownloadManager : NSObject<NSURLSessionDownloadDelegate, NSURLSessionTaskDelegate>
@property long bytesWritten;
@property long totalBytes;
@property BOOL downloadComplete;

- (instancetype)initWithURL:(NSURL *)url savePath:(NSURL *)path;
- (void)startDownload;
- (void)pauseDownload;
- (void)resumeDownload;
@end
