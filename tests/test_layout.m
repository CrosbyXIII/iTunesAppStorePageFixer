#import <Foundation/Foundation.h>
#import "FeaturedLayout.h"
#import "Fixtures.h"
#include <assert.h>

static NSString *render(NSData *data, NSString *url) {
    NSData *result = FRIPadPage(data, [NSURL URLWithString:url]);
    assert(result);
    return [[[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding] autorelease];
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *appsURL = @"https://apps.apple.com/WebObjects/MZStore.woa/wa/viewAppsMain";
    NSString *html = render(FRAppFixture(), appsURL);
    assert([html rangeOfString:@"Example &amp; Test"].location != NSNotFound);
    assert([html rangeOfString:@"https://apps.apple.com/us/app/example/id123"].location != NSNotFound);
    assert([html rangeOfString:@"width:20%"].location != NSNotFound);
    assert([html rangeOfString:@"width:16.6666%"].location != NSNotFound);
    html = render(FRPodcastFixture(), @"https://itunes.apple.com/us/rss/toppodcasts/limit=30/json");
    assert([html rangeOfString:@"Top Podcasts"].location != NSNotFound);
    assert([html rangeOfString:@"https://podcasts.apple.com/us/podcast/example/id123"].location != NSNotFound);
    html = render(FRChartFixture(), @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/topChartFragmentData?cc=gb&genreId=6014&popId=44");
    for (NSString *text in [NSArray arrayWithObjects:@"Top iPad Charts", @"Previous 30", @"Next 30", @"cc=gb&amp;genreId=6014", @"top-ten-m=3", nil])
        assert([html rangeOfString:text].location != NSNotFound);
    for (NSString *url in [NSArray arrayWithObjects:
        @"https://music.apple.com/us/album/example/123", @"https://itunes.apple.com/us/movie/example/id123",
        @"https://itunes.apple.com/us/tv-show/example/id123", @"https://books.apple.com/us/audiobook/example/id123",
        @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewAutoSourcedGenrePage?id=6014", nil]) {
        html = render(FRListFixture(url), @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewGrouping?id=39");
        assert([html rangeOfString:url].location != NSNotFound);
        assert([html rangeOfString:@"Sample &lt;Title&gt;"].location != NSNotFound);
        if ([url rangeOfString:@"/movie/"].location != NSNotFound)
            assert([html rangeOfString:@"class=\"fr-card fr-poster\""].location != NSNotFound);
    }
    NSURL *url = [NSURL URLWithString:appsURL];
    assert(FRIPadPage([@"<html>Error</html>" dataUsingEncoding:NSUTF8StringEncoding], url) == nil);
    assert(FRIPadPage([NSMutableData dataWithLength:2*1024*1024+1], url) == nil);
    assert(FRIPadPage(FRListFixture(@"https://apps.apple.com.attacker.invalid/app/id123"), url) == nil);
    puts("PASS: synthetic catalog rendering, original links, escaping, chart paging, poster styles, invalid/oversize responses");
    [pool drain];
    return 0;
}
