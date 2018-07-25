#import <MessageUI/MessageUI.h>
#import "RNMail.h"
#import <React/RCTConvert.h>
#import <React/RCTLog.h>

@implementation RNMail
{
    NSMutableDictionary *_callbacks;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _callbacks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(mail:(NSDictionary *)options
                  callback: (RCTResponseSenderBlock)callback)
{
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
        mail.mailComposeDelegate = self;
        _callbacks[RCTKeyForInstance(mail)] = callback;

        if (options[@"subject"]){
            NSString *subject = [RCTConvert NSString:options[@"subject"]];
            [mail setSubject:subject];
        }
        
        bool *isHTML = NO;
        
        if (options[@"isHTML"]){
            isHTML = [options[@"isHTML"] boolValue];
        }

        if (options[@"body"]){
            NSString *body = [RCTConvert NSString:options[@"body"]];
            [mail setMessageBody:body isHTML:isHTML];
        }

        if (options[@"recipients"]){
            NSArray *recipients = [RCTConvert NSArray:options[@"recipients"]];
            [mail setToRecipients:recipients];
        }

        if (options[@"ccRecipients"]){
            NSArray *ccRecipients = [RCTConvert NSArray:options[@"ccRecipients"]];
            [mail setCcRecipients:ccRecipients];
        }
        
        if (options[@"bccRecipients"]){
            NSArray *bccRecipients = [RCTConvert NSArray:options[@"bccRecipients"]];
            [mail setBccRecipients:bccRecipients];
        }

       if (options[@"attachments"]){
        NSArray<NSDictionary *> *attachments = [RCTConvert NSDictionaryArray:options[@"attachments"]];
        for(int i = 0; i < [attachments count]; ++i) {
            NSDictionary * attachmentItem = attachments[i];
            NSString *attachmentName = [RCTConvert NSString:attachmentItem[@"name"]];
            NSString *attachmentPath = [RCTConvert NSString:attachmentItem[@"path"]];
            NSString *mimeType = [RCTConvert NSString:attachmentItem[@"mimeType"]];
            
            if (!mimeType) {
            mimeType = lookupMimeByFileExtension(attachmentPath);
            }

            // Read file data to add to mime attachment
            NSData *fileData = [NSData dataWithContentsOfFile:attachmentPath];
            [mail addAttachmentData:fileData mimeType:mimeType fileName:attachmentName];
        }

        }

        UIViewController *root = [[[[UIApplication sharedApplication] delegate] window] rootViewController];

        while (root.presentedViewController) {
            root = root.presentedViewController;
        }
        [root presentViewController:mail animated:YES completion:nil];
    } else {
        callback(@[@"not_available"]);
    }
}

#pragma mark MFMailComposeViewControllerDelegate Methods

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    NSString *key = RCTKeyForInstance(controller);
    RCTResponseSenderBlock callback = _callbacks[key];
    if (callback) {
        switch (result) {
            case MFMailComposeResultSent:
                callback(@[[NSNull null] , @"sent"]);
                break;
            case MFMailComposeResultSaved:
                callback(@[[NSNull null] , @"saved"]);
                break;
            case MFMailComposeResultCancelled:
                callback(@[[NSNull null] , @"cancelled"]);
                break;
            case MFMailComposeResultFailed:
                callback(@[@"failed"]);
                break;
            default:
                callback(@[@"error"]);
                break;
        }
        [_callbacks removeObjectForKey:key];
    } else {
        RCTLogWarn(@"No callback registered for mail: %@", controller.title);
    }
    UIViewController *ctrl = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    while (ctrl.presentedViewController && ctrl != controller) {
        ctrl = ctrl.presentedViewController;
    }
    [ctrl dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Private

static NSString *RCTKeyForInstance(id instance)
{
    return [NSString stringWithFormat:@"%p", instance];
}

// Consider a data lookup table that has analogy in Java and Objective C
// so mime type data is maintained in single location.
static const StructFileExtensionMimePair_t lookupMimeTypeByFileExtension[] = {
  { "csv",    "text/csv" },
  { "doc",    "application/msword" },
  { "gpx",    "application/gpx+xml" },
  { "html",   "text/html" },
  { "jpg",    "image/jpeg" },
  { "kml",    "application/vnd.google-earth.kml+xml" },
  { "png",    "image/png" },
  { "ppt",    "application/vnd.ms-powerpoint" },
  { "pdf",    "application/pdf" },
  { "tsr",    "application/vnd.ditchwitch.tsr+xml" },
  { "tsl",    "application/vnd.ditchwitch.tsl+xml" },
  { "txt",    "text/plain" }
};

// Consider a data lookup table that has analogy in Java and Objective C.
// Is there a common file or data format that could be accessed by both Java and Objective C.
// Or a script to update or generate cross platform data file?
static NSString *lookupMimeByFileExtension(NSString* fileName)
{
  NSString *mimeType = @"application/octet-stream";
  NSString* extension = [fileName pathExtension];

  for(int i = 0; i < (sizeof(lookupMimeTypeByFileExtension)/sizeof(StructFileExtensionMimePair_t)); ++i) {
    if (NSOrderedSame == [extension caseInsensitiveCompare:[NSString stringWithUTF8String:lookupMimeTypeByFileExtension[i].fileExtension]] ) {
      mimeType = @"text/plain";
      break;
    }
  }
  return mimeType;
}

@end
