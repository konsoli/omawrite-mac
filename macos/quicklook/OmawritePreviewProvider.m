// Quick Look preview extension: renders Markdown files the way Omawrite renders
// them, in the same palette and the same typeface. Deliberately Qt-free — the
// extension is a separate, sandboxed process launched by quicklookd, so it only
// links system frameworks plus the vendored md4c parser (the same parser Qt uses
// behind QTextDocument::setMarkdown).

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <QuickLookUI/QuickLookUI.h>

#include "md4c-html.h"

// Previews are for reading the top of a document, not for loading all of it.
static const NSUInteger kMaxPreviewBytes = 2u * 1024 * 1024;

// The bundled face, the same one the editor writes in. It is not installed
// system-wide, so the preview carries its own copy of the files.
static NSString *const kFontFamily = @"iA Writer Mono S";

static NSString *fontFace(NSBundle *bundle, NSString *resource, NSString *weight,
                          NSString *style) {
    NSURL *url = [bundle URLForResource:resource withExtension:@"ttf"];
    if (!url)
        return @"";

    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data)
        return @"";

    return [NSString stringWithFormat:
        @"@font-face{font-family:'%@';font-weight:%@;font-style:%@;font-display:block;"
         "src:url(data:font/ttf;base64,%@) format('truetype');}\n",
        kFontFamily, weight, style, [data base64EncodedStringWithOptions:0]];
}

static NSString *embeddedFonts(NSBundle *bundle) {
    NSMutableString *css = [NSMutableString string];
    [css appendString:fontFace(bundle, @"iAWriterMonoS-Regular", @"400", @"normal")];
    [css appendString:fontFace(bundle, @"iAWriterMonoS-Italic", @"400", @"italic")];
    [css appendString:fontFace(bundle, @"iAWriterMonoS-Bold", @"700", @"normal")];
    [css appendString:fontFace(bundle, @"iAWriterMonoS-BoldItalic", @"700", @"italic")];
    return css;
}

// Reads at most kMaxPreviewBytes. A cut in the middle of a UTF-8 sequence would
// fail to decode, so back off a few bytes before falling through to Latin-1.
static NSString *readMarkdown(NSURL *fileURL, NSError **error) {
    NSData *data = [NSData dataWithContentsOfURL:fileURL
                                         options:NSDataReadingMappedIfSafe
                                           error:error];
    if (!data)
        return nil;

    if (data.length > kMaxPreviewBytes)
        data = [data subdataWithRange:NSMakeRange(0, kMaxPreviewBytes)];

    for (NSUInteger trim = 0; trim < 4 && trim < data.length; ++trim) {
        NSData *candidate = [data subdataWithRange:NSMakeRange(0, data.length - trim)];
        NSString *text = [[NSString alloc] initWithData:candidate
                                               encoding:NSUTF8StringEncoding];
        if (text)
            return text;
    }

    NSString *latin1 = [[NSString alloc] initWithData:data
                                             encoding:NSISOLatin1StringEncoding];
    return latin1 ?: @"";
}

static void appendHtmlChunk(const MD_CHAR *text, MD_SIZE size, void *userdata) {
    [(__bridge NSMutableData *)userdata appendBytes:text length:size];
}

static NSString *renderMarkdown(NSString *markdown) {
    NSData *utf8 = [markdown dataUsingEncoding:NSUTF8StringEncoding];
    if (!utf8)
        return @"";

    NSMutableData *html = [NSMutableData dataWithCapacity:utf8.length * 2];
    // MD_FLAG_NOHTML: a previewed file is untrusted input, so raw HTML in the
    // Markdown never reaches the preview.
    const int result = md_html((const MD_CHAR *)utf8.bytes, (MD_SIZE)utf8.length,
                               appendHtmlChunk, (__bridge void *)html,
                               MD_DIALECT_GITHUB | MD_FLAG_NOHTML,
                               MD_HTML_FLAG_SKIP_UTF8_BOM);
    if (result != 0)
        return @"";

    return [[NSString alloc] initWithData:html encoding:NSUTF8StringEncoding] ?: @"";
}

// The system appearance, so the preview can pin the palette instead of trusting
// prefers-color-scheme inside the Quick Look web view. Returns nil when the
// preference is absent (light mode, or unreadable), and the CSS media query
// decides instead.
static NSString *interfaceStyleAttribute(void) {
    NSString *style = [[NSUserDefaults standardUserDefaults]
        stringForKey:@"AppleInterfaceStyle"];
    if ([style hasPrefix:@"Dark"])
        return @" data-theme=\"dark\"";
    return @"";
}

// The whole preview document: embedded fonts, the stylesheet from the
// extension's own resources, and the rendered Markdown.
static NSData *previewDocument(NSURL *fileURL, NSBundle *bundle, NSError **error) {
    NSString *markdown = readMarkdown(fileURL, error);
    if (!markdown)
        return nil;

    NSURL *cssURL = [bundle URLForResource:@"preview" withExtension:@"css"];
    NSString *css = cssURL ? [NSString stringWithContentsOfURL:cssURL
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil]
                           : nil;

    NSString *document = [NSString stringWithFormat:
        @"<!DOCTYPE html>\n<html%@>\n<head>\n"
         "<meta charset=\"utf-8\">\n"
         "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; "
         "style-src 'unsafe-inline'; font-src data:; img-src data:;\">\n"
         "<style>\n%@%@</style>\n</head>\n<body>\n<main>\n%@</main>\n</body>\n</html>\n",
        interfaceStyleAttribute(), embeddedFonts(bundle), css ?: @"",
        renderMarkdown(markdown)];

    return [document dataUsingEncoding:NSUTF8StringEncoding];
}

@interface OmawritePreviewProvider : QLPreviewProvider <QLPreviewingController>
@end

@implementation OmawritePreviewProvider

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
                   completionHandler:(void (^)(QLPreviewReply *_Nullable,
                                               NSError *_Nullable))handler {
    NSURL *fileURL = request.fileURL;
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    QLPreviewReply *reply = [[QLPreviewReply alloc]
        initWithDataOfContentType:UTTypeHTML
                      contentSize:CGSizeMake(800, 1000)
                dataCreationBlock:^NSData *_Nullable(QLPreviewReply *reply,
                                                     NSError **error) {
        reply.stringEncoding = NSUTF8StringEncoding;
        reply.title = fileURL.lastPathComponent ?: @"";
        return previewDocument(fileURL, bundle, error);
    }];

    handler(reply, nil);
}

@end
