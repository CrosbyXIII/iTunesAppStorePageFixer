// Synthetic catalog fixtures; no account data or captured server responses.
#import <Foundation/Foundation.h>

static inline NSData *FRAppFixture(void) {
    return [@"<div class=\"lockup application\"><a href=\"https://apps.apple.com/us/app/example/id123\" preview-title=\"Example &amp; Test\" preview-artist=\"Sample Developer\" src-swap=\"https://is1.mzstatic.com/example.png\"></a><div class=\"buy-line\"><span>GET</span></div></div>" dataUsingEncoding:NSUTF8StringEncoding];
}

static inline NSData *FRPodcastFixture(void) {
    return [@"{\"feed\":{\"entry\":[{\"id\":{\"label\":\"https://podcasts.apple.com/us/podcast/example/id123\"},\"im:name\":{\"label\":\"Sample Podcast\"},\"im:artist\":{\"label\":\"Example Artist\"},\"im:image\":[{\"label\":\"https://is1.mzstatic.com/example.png\"}]}]}}" dataUsingEncoding:NSUTF8StringEncoding];
}

static inline NSData *FRChartFixture(void) {
    NSMutableArray *items = [NSMutableArray array];
    for (int i = 0; i < 30; i++) [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        [NSString stringWithFormat:@"https://apps.apple.com/us/app/example/id%d", 100+i], @"url",
        [NSString stringWithFormat:@"Sample app %d", i+1], @"name", @"GET", @"button_text",
        @"https://is1.mzstatic.com/example.png", @"artwork_url", nil]];
    NSDictionary *page = [NSDictionary dictionaryWithObjectsAndKeys:items, @"contentData", [NSNumber numberWithInt:1], @"pageNumber", nil];
    return [NSJSONSerialization dataWithJSONObject:[NSArray arrayWithObject:page] options:0 error:NULL];
}

static inline NSData *FRListFixture(NSString *url) {
    NSDictionary *item = [NSDictionary dictionaryWithObjectsAndKeys:@"link", @"type", url, @"url",
        @"Sample <Title>", @"title", @"Sample Artist", @"artist-name", nil];
    NSDictionary *list = [NSDictionary dictionaryWithObjectsAndKeys:@"Sample Section", @"title", [NSArray arrayWithObject:item], @"items", nil];
    NSString *error = nil;
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:list format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
    [error release];
    return data;
}
