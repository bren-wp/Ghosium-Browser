package com.brendigo.ghosium;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
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
        // A host with an explicit port (for example localhost:8443) must be
        // classified before the generic URI-scheme rule. Otherwise the host
        // prefix is incorrectly interpreted as a custom scheme.
        if (looksLikeHost(value)) {
            return "https://" + value;
        }
        if (SCHEME.matcher(value).matches()) {
            return value;
        }
        return "https://www.google.com/search?q=" + encodeQuery(value);
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

    private static String encodeQuery(String value) {
        try {
            // String/String overload works on every supported Android API.
            return URLEncoder.encode(value, "UTF-8");
        } catch (UnsupportedEncodingException impossible) {
            // UTF-8 is required by every Android runtime. Fail closed rather
            // than leaking an unescaped query if a non-conforming runtime is used.
            throw new IllegalStateException("UTF-8 is unavailable", impossible);
        }
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
            int portValue;
            try {
                portValue = Integer.parseInt(port);
            } catch (NumberFormatException error) {
                return false;
            }
            if (portValue < 1 || portValue > 65535) {
                return false;
            }
            hostPart = hostPart.substring(0, colon);
        }
        return "localhost".equalsIgnoreCase(hostPart) ||
                hostPart.contains(".") || hostPart.matches("(?:\\d{1,3}\\.){3}\\d{1,3}");
    }
}
