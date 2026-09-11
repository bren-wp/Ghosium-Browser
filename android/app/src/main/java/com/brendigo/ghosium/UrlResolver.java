package com.brendigo.ghosium;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.regex.Pattern;

final class UrlResolver {
    static final String NEW_TAB_URL = "https://appassets.androidplatform.net/assets/newtab.html";
    private static final Pattern SCHEME = Pattern.compile("^[a-zA-Z][a-zA-Z0-9+.-]*:.*$");
    private static final Pattern WHITESPACE = Pattern.compile(".*\\s+.*");

    private UrlResolver() {}

    static String resolve(String raw) {
        String value = raw == null ? "" : raw.trim();
        if (value.isEmpty()) {
            return NEW_TAB_URL;
        }

        String lower = value.toLowerCase(Locale.ROOT);
        if (lower.startsWith("http://") || lower.startsWith("https://")) {
            return value;
        }
        if (SCHEME.matcher(value).matches()) {
            return value;
        }
        if (looksLikeHost(value)) {
            return "https://" + value;
        }
        return "https://www.google.com/search?q=" +
                URLEncoder.encode(value, StandardCharsets.UTF_8);
    }

    static boolean isHttpOrHttps(String value) {
        if (value == null) {
            return false;
        }
        String lower = value.toLowerCase(Locale.ROOT);
        return lower.startsWith("https://") || lower.startsWith("http://");
    }

    static boolean isNewTab(String value) {
        return NEW_TAB_URL.equals(value);
    }

    private static boolean looksLikeHost(String value) {
        if (WHITESPACE.matcher(value).matches() || value.startsWith(".") || value.endsWith(".")) {
            return false;
        }
        String hostPart = value;
        int slash = hostPart.indexOf('/');
        if (slash >= 0) {
            hostPart = hostPart.substring(0, slash);
        }
        int colon = hostPart.lastIndexOf(':');
        if (colon > 0 && hostPart.indexOf(':') == colon) {
            String port = hostPart.substring(colon + 1);
            if (!port.matches("\\d{1,5}")) {
                return false;
            }
            hostPart = hostPart.substring(0, colon);
        }
        return "localhost".equalsIgnoreCase(hostPart) ||
                hostPart.contains(".") || hostPart.matches("(?:\\d{1,3}\\.){3}\\d{1,3}");
    }
}
