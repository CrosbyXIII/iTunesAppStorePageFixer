#import <objc/runtime.h>
#import "FeaturedLayout.h"
#import "FeaturedPolicy.h"

static NSString *FRText(id value) {
    return [value isKindOfClass:[objc_getClass("NSString") class]] ? value : @"";
}

static NSString *FREscape(id value) {
    NSString *s = FRText(value);
    s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    s = [s stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    s = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
    return [s stringByReplacingOccurrencesOfString:@"'" withString:@"&#39;"];
}

static NSString *FRDecode(NSString *s) {
    s = [s stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
    s = [s stringByReplacingOccurrencesOfString:@"&#39;" withString:@"'"];
    s = [s stringByReplacingOccurrencesOfString:@"&apos;" withString:@"'"];
    s = [s stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    s = [s stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    s = [s stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@" "];
    return [s stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
}

static NSString *FRCapture(NSString *source, NSString *pattern) {
    NSRegularExpression *re = [objc_getClass("NSRegularExpression") regularExpressionWithPattern:pattern options:NSRegularExpressionDotMatchesLineSeparators error:NULL];
    NSTextCheckingResult *m = [re firstMatchInString:source options:0 range:NSMakeRange(0, [source length])];
    return m && [m numberOfRanges] > 1 ? [source substringWithRange:[m rangeAtIndex:1]] : @"";
}

static NSString *FRAttribute(NSString *source, NSString *name) {
    NSString *pattern = [objc_getClass("NSString") stringWithFormat:@"(?:^|[\\s<])%@[\\s]*=[\\s]*\"([^\"]*)\"", name];
    return FRDecode(FRCapture(source, pattern));
}

static BOOL FRProductURL(NSString *value) {
    NSURL *url = [objc_getClass("NSURL") URLWithString:value];
    if (![[url scheme] isEqualToString:@"https"]) return NO;
    NSString *host = [[url host] lowercaseString];
    return [host isEqualToString:@"apps.apple.com"] || [host isEqualToString:@"music.apple.com"] || [host isEqualToString:@"itunes.apple.com"] || [host isEqualToString:@"books.apple.com"] || [host isEqualToString:@"podcasts.apple.com"];
}

static BOOL FRArtworkURL(NSString *value) {
    NSURL *url = [objc_getClass("NSURL") URLWithString:value];
    return [[url scheme] isEqualToString:@"https"] && [[[url host] lowercaseString] hasSuffix:@".mzstatic.com"];
}

static NSString *FRCard(NSString *url, NSString *art, NSString *name, NSString *artist, NSString *detail, BOOL app) {
    if (!FRProductURL(url) || ![name length]) return @"";
    NSString *image = FRArtworkURL(art) ? [objc_getClass("NSString") stringWithFormat:@"<img class=\"fr-art\" src=\"%@\" alt=\"\" />", FREscape(art)] : @"<span class=\"fr-art fr-no-art\">&#9835;</span>";
    BOOL poster = [url rangeOfString:@"/movie/"].location != NSNotFound;
    return [objc_getClass("NSString") stringWithFormat:@"<a class=\"fr-card %@\" href=\"%@\" onclick=\"return frOpen(this)\">%@<span class=\"fr-name\">%@</span><span class=\"fr-artist\">%@</span><span class=\"fr-detail\">%@</span></a>", app ? @"fr-app" : (poster ? @"fr-poster" : @"fr-album"), FREscape(url), image, FREscape(name), FREscape(artist), FREscape(detail)];
}

static NSString *FRPage(NSString *title, NSString *navigation, NSString *body) {
    return [objc_getClass("NSString") stringWithFormat:
        @"<!DOCTYPE html><html xmlns=\"http://www.apple.com/itms/\"><head><meta charset=\"utf-8\" />"
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0,maximum-scale=1.0\" /><title>%@</title>"
        "<style>html,body{margin:0;padding:0;width:100%%;min-height:100%%;background:#f5f5f5;color:#222;font-family:Helvetica,Arial,sans-serif;-webkit-text-size-adjust:100%%}"
        "*{-webkit-box-sizing:border-box;box-sizing:border-box}a{text-decoration:none;color:inherit;-webkit-tap-highlight-color:rgba(45,100,170,.18)}"
        ".fr-nav{text-align:center;padding:18px 12px;background:-webkit-linear-gradient(top,#f8f8f8,#dedee2);border-bottom:1px solid #b7b7bc}"
        ".fr-tab{display:inline-block;padding:8px 26px;border:1px solid #a1a4aa;margin-left:-1px;font-size:13px;font-weight:bold;color:#50545c;background:-webkit-linear-gradient(top,#fff,#d9dce2);text-shadow:0 1px #fff}"
        ".fr-tab:first-child{border-radius:6px 0 0 6px}.fr-tab:last-child{border-radius:0 6px 6px 0}.fr-tab.fr-active{background:-webkit-linear-gradient(top,#7c8491,#4e5869);color:#fff;text-shadow:0 -1px #555}"
        "h2{clear:both;margin:0;padding:17px 24px 11px;font-size:19px;line-height:25px;font-weight:bold;color:#424a56;text-shadow:0 1px #fff;border-bottom:1px solid #d7d7db;background:#ececef}"
        ".fr-grid{padding:14px 15px 10px;font-size:0;background:#fff;border-bottom:1px solid #c7c7cc}"
        ".fr-card{display:inline-block;vertical-align:top;width:20%%;height:234px;padding:10px 14px 16px;text-align:left;font-size:13px;overflow:hidden}"
        ".fr-art{display:block;width:112px;height:112px;max-width:100%%;margin:0 auto 10px;-webkit-box-shadow:0 1px 4px rgba(0,0,0,.24);object-fit:cover}.fr-app .fr-art{border-radius:18px}"
        ".fr-no-art{background:#dde1e8;color:#88909b;text-align:center;line-height:112px;font-size:46px}"
        ".fr-name{display:block;font-size:13px;line-height:17px;height:34px;font-weight:bold;overflow:hidden}"
        ".fr-artist{display:block;font-size:12px;line-height:18px;color:#7d7d83;white-space:nowrap;text-overflow:ellipsis;overflow:hidden}"
        ".fr-detail{display:block;font-size:11px;line-height:20px;color:#52647a;white-space:nowrap;text-overflow:ellipsis;overflow:hidden}"
        ".fr-card.fr-poster{height:294px}.fr-poster .fr-art{width:112px;height:168px}.fr-more{display:block;padding:20px;text-align:center;font-size:17px;font-weight:bold;color:#385980;border-bottom:1px solid #ccc;background:#f3f3f5}"
        "@media(min-width:900px){.fr-card{width:16.6666%%;height:242px}.fr-art{width:120px;height:120px}}"
        "@media(max-width:600px){.fr-card{width:33.3333%%;padding-left:8px;padding-right:8px}.fr-art{width:90px;height:90px}.fr-nav{padding:12px 4px}.fr-tab{padding:8px 13px}}"
        "</style><script>function frOpen(a){try{if(window.iTunes&&typeof iTunes.gotoURL==='function'){iTunes.gotoURL(a.href);return false;}}catch(e){}return true;}</script>"
        "</head><body>%@%@</body></html>", FREscape(title), navigation, body];
}

static NSString *FRApps(NSString *source) {
    NSRegularExpression *re = [objc_getClass("NSRegularExpression") regularExpressionWithPattern:@"<div[^>]*class\\s*=\\s*\"lockup application\"[^>]*>" options:0 error:NULL];
    NSArray *matches = [re matchesInString:source options:0 range:NSMakeRange(0, [source length])];
    if (![matches count]) return nil;
    NSMutableString *cards = (NSMutableString *)[objc_getClass("NSMutableString") string];
    NSMutableSet *seen = (NSMutableSet *)[objc_getClass("NSMutableSet") set];
    for (NSUInteger i = 0; i < [matches count]; i++) {
        NSRange range = [[matches objectAtIndex:i] range];
        NSUInteger end = i + 1 < [matches count] ? [[matches objectAtIndex:i + 1] range].location : [source length];
        NSString *chunk = [source substringWithRange:NSMakeRange(range.location, end - range.location)];
        NSString *url = FRAttribute(chunk, @"href");
        if ([seen containsObject:url]) continue;
        [seen addObject:url];
        NSString *art = FRAttribute(chunk, @"src-swap-high-dpi");
        if (![art length]) art = FRAttribute(chunk, @"src-swap");
        NSString *price = FRCapture(chunk, @"<div class=\"buy-line\">.*?<span[^>]*>(.*?)</span>");
        [cards appendString:FRCard(url, art, FRAttribute(chunk, @"preview-title"), FRAttribute(chunk, @"preview-artist"), FRDecode(price), YES)];
    }
    if (![cards length]) return nil;
    return FRPage(@"App Store", @"", [objc_getClass("NSString") stringWithFormat:@"<h2>Featured</h2><div class=\"fr-grid\">%@</div>", cards]);
}

static NSString *FRPlist(NSData *data) {
    NSString *error = nil;
    id plist = [objc_getClass("NSPropertyListSerialization") propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&error];
    [error release];
    if (![plist isKindOfClass:[objc_getClass("NSDictionary") class]]) return nil;
    id items = [plist objectForKey:@"items"];
    if (![items isKindOfClass:[objc_getClass("NSArray") class]]) return nil;
    NSMutableString *nav = [objc_getClass("NSMutableString") stringWithString:@"<div class=\"fr-nav\">"];
    NSDictionary *navigation = [plist objectForKey:@"tabs"];
    NSArray *tabs = [navigation isKindOfClass:[objc_getClass("NSDictionary") class]] ? [navigation objectForKey:@"tabs"] : nil;
    if ([tabs isKindOfClass:[objc_getClass("NSArray") class]]) for (NSDictionary *tab in tabs) {
        if (![tab isKindOfClass:[objc_getClass("NSDictionary") class]]) continue;
        NSString *url = FRText([tab objectForKey:@"url"]);
        if (FRProductURL(url)) [nav appendFormat:@"<a class=\"fr-tab %@\" href=\"%@\" onclick=\"return frOpen(this)\">%@</a>", [[tab objectForKey:@"active-tab"] boolValue] ? @"fr-active" : @"", FREscape(url), FREscape([tab objectForKey:@"title"])];
    }
    [nav appendString:@"</div>"];
    NSMutableString *body = (NSMutableString *)[objc_getClass("NSMutableString") string];
    NSString *title = FRText([plist objectForKey:@"title"]);
    if ([title length]) [body appendFormat:@"<h2>%@</h2>", FREscape(title)];
    NSMutableString *more = (NSMutableString *)[objc_getClass("NSMutableString") string];
    BOOL open = NO;
    NSUInteger count = 0;
    for (NSDictionary *item in items) {
        if (![item isKindOfClass:[objc_getClass("NSDictionary") class]]) continue;
        if ([FRText([item objectForKey:@"type"]) isEqualToString:@"more"]) {
            if (FRProductURL(FRText([item objectForKey:@"url"]))) [more appendFormat:@"<a class=\"fr-more\" href=\"%@\" onclick=\"return frOpen(this)\">%@</a>", FREscape([item objectForKey:@"url"]), FREscape([item objectForKey:@"title"])];
        } else if ([FRText([item objectForKey:@"type"]) isEqualToString:@"separator"]) {
            if (![FRText([item objectForKey:@"title"]) length]) continue;
            if (open) [body appendString:@"</div>"];
            [body appendFormat:@"<h2>%@</h2><div class=\"fr-grid\">", FREscape([item objectForKey:@"title"])];
            open = YES;
        } else if ([FRText([item objectForKey:@"type"]) isEqualToString:@"link"]) {
            NSString *art = @"";
            id images = [item objectForKey:@"artwork-urls"];
            if (!images && [[item objectForKey:@"content"] isKindOfClass:objc_getClass("NSDictionary")]) images = [[item objectForKey:@"content"] objectForKey:@"artwork-urls"];
            if ([images isKindOfClass:[objc_getClass("NSArray") class]]) for (NSDictionary *image in images) {
                if ([image isKindOfClass:[objc_getClass("NSDictionary") class]] && FRArtworkURL(FRText([image objectForKey:@"url"]))) art = [image objectForKey:@"url"];
            }
            BOOL app = [FRText([item objectForKey:@"link-type"]) isEqualToString:@"software"] || [FRText([plist objectForKey:@"store-client-application"]) isEqualToString:@"Software"];
            NSString *detail = FRText([item objectForKey:@"user-rating-count-string"]);
            id offers = [item objectForKey:@"store-offers"];
            if ([offers isKindOfClass:objc_getClass("NSDictionary")]) {
                id offer = [offers objectForKey:@"STDQ"];
                if ([offer isKindOfClass:objc_getClass("NSDictionary")] && [FRText([offer objectForKey:@"price-display"]) length]) detail = [offer objectForKey:@"price-display"];
            }
            NSString *card = FRCard(FRText([item objectForKey:@"url"]), art, FRText([item objectForKey:@"title"]), FRText([item objectForKey:@"artist-name"]), detail, app);
            if ([card length]) {
                if (!open) { [body appendString:@"<div class=\"fr-grid\">"]; open = YES; }
                [body appendString:card]; count++;
            }
        }
        // Empty squish-row banners carry links but no images; omit their blank height.
    }
    if (open) [body appendString:@"</div>"];
    [body appendString:more];
    if (!count) return nil;
    return FRPage(title, nav, body);
}

static NSString *FRPodcasts(NSData *data) {
    id root = [objc_getClass("NSJSONSerialization") JSONObjectWithData:data options:0 error:NULL];
    if (![root isKindOfClass:objc_getClass("NSDictionary")]) return nil;
    id feed = [root objectForKey:@"feed"];
    if (![feed isKindOfClass:objc_getClass("NSDictionary")]) return nil;
    id entries = [feed objectForKey:@"entry"];
    if (![entries isKindOfClass:objc_getClass("NSArray")]) return nil;
    NSMutableString *cards = (NSMutableString *)[objc_getClass("NSMutableString") string];
    for (NSDictionary *entry in entries) {
        if (![entry isKindOfClass:objc_getClass("NSDictionary")]) continue;
        NSString *url = FRText([[entry objectForKey:@"id"] objectForKey:@"label"]);
        NSString *art = @"";
        for (NSDictionary *image in [entry objectForKey:@"im:image"]) {
            if ([image isKindOfClass:objc_getClass("NSDictionary")] && FRArtworkURL(FRText([image objectForKey:@"label"]))) art = [image objectForKey:@"label"];
        }
        [cards appendString:FRCard(url,art,FRText([[entry objectForKey:@"im:name"] objectForKey:@"label"]),FRText([[entry objectForKey:@"im:artist"] objectForKey:@"label"]),@"Podcast",NO)];
    }
    if (![cards length]) return nil;
    return FRPage(@"Podcasts", @"", [objc_getClass("NSString") stringWithFormat:@"<h2>Top Podcasts</h2><div class=\"fr-grid\">%@</div>",cards]);
}

static NSString *FRCharts(NSData *data, NSURL *url) {
    id pages = [objc_getClass("NSJSONSerialization") JSONObjectWithData:data options:0 error:NULL];
    if (![pages isKindOfClass:objc_getClass("NSArray")] || ![pages count]) return nil;
    id page = [pages objectAtIndex:0];
    if (![page isKindOfClass:objc_getClass("NSDictionary")]) return nil;
    id items = [page objectForKey:@"contentData"];
    if (![items isKindOfClass:objc_getClass("NSArray")]) return nil;
    NSMutableString *cards = (NSMutableString *)[objc_getClass("NSMutableString") string];
    for (NSDictionary *item in items) {
        if (![item isKindOfClass:objc_getClass("NSDictionary")]) continue;
        id buyData = [item objectForKey:@"buyData"];
        NSString *artist = [buyData isKindOfClass:objc_getClass("NSDictionary")] ? FRText([buyData objectForKey:@"artist-name"]) : @"";
        NSString *art = FRText([item objectForKey:@"artwork_2x_url"]);
        if (![art length]) art = FRText([item objectForKey:@"artwork_url"]);
        [cards appendString:FRCard(FRText([item objectForKey:@"url"]),art,FRText([item objectForKey:@"name"]),artist,FRText([item objectForKey:@"button_text"]),YES)];
    }
    NSInteger pop = [FRQueryValue(url,@"popId") integerValue];
    NSInteger selected = pop == 44 ? 1 : (pop == 46 ? 2 : 0);
    NSInteger genre = [FRQueryValue(url,@"genreId") integerValue];
    NSInteger pageNumber = [[page objectForKey:@"pageNumber"] integerValue];
    NSString *country = FRQueryValue(url,@"cc") ?: @"us";
    NSArray *titles = [objc_getClass("NSArray") arrayWithObjects:@"Paid",@"Free",@"Top Grossing",nil];
    NSMutableString *nav = [objc_getClass("NSMutableString") stringWithString:@"<div class=\"fr-nav\">"];
    for (NSInteger tab = 0; tab < 3; tab++) {
        NSString *link = [objc_getClass("NSString") stringWithFormat:@"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewTop?cc=%@&genreId=%ld&selected-tab-index=%ld",country,(long)genre,(long)tab];
        [nav appendFormat:@"<a class=\"fr-tab %@\" href=\"%@\" onclick=\"return frOpen(this)\">%@</a>",tab==selected ? @"fr-active" : @"",FREscape(link),[titles objectAtIndex:tab]];
    }
    [nav appendString:@"</div>"];
    NSMutableString *body = [objc_getClass("NSMutableString") stringWithFormat:@"<h2>Top iPad Charts</h2><div class=\"fr-grid\">%@</div>",cards];
    if (pageNumber > 0 || [items count] == 30) {
        for (NSInteger delta = -1; delta <= 1; delta += 2) {
            NSInteger target = pageNumber + delta;
            if (target < 0 || target > 9 || (delta > 0 && [items count] < 30)) continue;
            NSString *link = [objc_getClass("NSString") stringWithFormat:@"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewTop?cc=%@&genreId=%ld&selected-tab-index=%ld&top-ten-m=%ld",country,(long)genre,(long)selected,(long)target+1];
            [body appendFormat:@"<a class=\"fr-more\" href=\"%@\" onclick=\"return frOpen(this)\">%@</a>",FREscape(link),delta<0 ? @"Previous 30" : @"Next 30"];
        }
    }
    if (![items count]) [body appendString:@"<h2>No more results</h2>"];
    return FRPage(@"Top Charts",nav,body);
}

NSData *FRIPadPage(NSData *data, NSURL *url) {
    if ([data length] > 2 * 1024 * 1024) return nil;
    NSString *html = nil;
    if ([[url path] hasSuffix:@"/topChartFragmentData"] && [[[url host] lowercaseString] isEqualToString:@"itunes.apple.com"]) {
        html = FRCharts(data,url);
    } else if ([[url path] rangeOfString:@"/rss/toppodcasts/"].location != NSNotFound && [[[url host] lowercaseString] isEqualToString:@"itunes.apple.com"]) {
        html = FRPodcasts(data);
    } else if ([[[url host] lowercaseString] isEqualToString:@"apps.apple.com"]) {
        NSString *source = [[[objc_getClass("NSString") alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        if (source) html = FRApps(source);
    }
    if (!html) html = FRPlist(data);
    return [html dataUsingEncoding:NSUTF8StringEncoding];
}
