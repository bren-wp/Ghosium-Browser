package com.brendigo.ghosium;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public final class UrlResolverTest {
    @Test
    public void emptyInputOpensNewTab() {
        assertEquals(UrlResolver.NEW_TAB_URL, UrlResolver.resolve("   "));
    }

    @Test
    public void httpsUrlIsPreserved() {
        assertEquals("https://example.com/a", UrlResolver.resolve("https://example.com/a"));
    }

    @Test
    public void httpUrlIsPreserved() {
        assertEquals("http://example.com", UrlResolver.resolve("http://example.com"));
    }

    @Test
    public void hostGetsHttps() {
        assertEquals("https://example.com/docs", UrlResolver.resolve("example.com/docs"));
    }

    @Test
    public void localhostGetsHttps() {
        assertEquals("https://localhost:8443/test", UrlResolver.resolve("localhost:8443/test"));
    }

    @Test
    public void queryUsesGoogle() {
        assertEquals("https://www.google.com/search?q=privacy+browser", UrlResolver.resolve("privacy browser"));
    }

    @Test
    public void externalSchemeIsPreservedForNativeDispatch() {
        assertEquals("mailto:hello@example.com", UrlResolver.resolve("mailto:hello@example.com"));
    }

    @Test
    public void schemeHelpersAreStrict() {
        assertTrue(UrlResolver.isHttpOrHttps("HTTPS://example.com"));
        assertFalse(UrlResolver.isHttpOrHttps("javascript:alert(1)"));
        assertTrue(UrlResolver.isNewTab(UrlResolver.NEW_TAB_URL));
    }
}
