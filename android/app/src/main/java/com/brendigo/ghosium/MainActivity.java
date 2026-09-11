package com.brendigo.ghosium;

import android.annotation.SuppressLint;
import android.app.DownloadManager;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Bundle;
import android.os.Environment;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.SslErrorHandler;
import android.webkit.URLUtil;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebStorage;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.EditText;
import android.widget.FrameLayout;

import androidx.activity.OnBackPressedCallback;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.brendigo.ghosium.databinding.ActivityMainBinding;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.snackbar.Snackbar;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Collections;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public final class MainActivity extends AppCompatActivity {
    private static final String STATE_LAST_URL = "ghosium.lastUrl";
    private static final String STATE_DESKTOP = "ghosium.desktop";
    private static final String APP_ASSET_HOST = "appassets.androidplatform.net";
    private static final String APP_ASSET_PREFIX = "/assets/";

    private ActivityMainBinding binding;
    private WebView webView;
    private String lastUrl = UrlResolver.NEW_TAB_URL;
    private String mobileUserAgent = "";
    private boolean desktopMode;
    private ValueCallback<Uri[]> pendingFileChooser;
    private ActivityResultLauncher<Intent> fileChooserLauncher;
    private View customView;
    private WebChromeClient.CustomViewCallback customViewCallback;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);

        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        applySystemBarInsets();

        fileChooserLauncher = registerForActivityResult(
                new ActivityResultContracts.StartActivityForResult(), result -> {
                    if (pendingFileChooser == null) {
                        return;
                    }
                    Uri[] resultUris = null;
                    Intent data = result.getData();
                    if (result.getResultCode() == RESULT_OK && data != null) {
                        ClipData clipData = data.getClipData();
                        if (clipData != null && clipData.getItemCount() > 0) {
                            resultUris = new Uri[clipData.getItemCount()];
                            for (int i = 0; i < clipData.getItemCount(); i++) {
                                resultUris[i] = clipData.getItemAt(i).getUri();
                            }
                        } else if (data.getData() != null) {
                            resultUris = new Uri[]{data.getData()};
                        }
                    }
                    pendingFileChooser.onReceiveValue(resultUris);
                    pendingFileChooser = null;
                });

        if (savedInstanceState != null) {
            lastUrl = savedInstanceState.getString(STATE_LAST_URL, UrlResolver.NEW_TAB_URL);
            desktopMode = savedInstanceState.getBoolean(STATE_DESKTOP, false);
        } else {
            String deepLink = getIntent() != null && getIntent().getData() != null
                    ? getIntent().getData().toString() : null;
            if (UrlResolver.isHttpOrHttps(deepLink)) {
                lastUrl = deepLink;
            }
        }

        configureNativeUi();
        createWebView(savedInstanceState);
        WebView.startSafeBrowsing(this, null);

        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                if (customView != null) {
                    hideCustomView();
                } else if (webView != null && webView.canGoBack()) {
                    webView.goBack();
                } else {
                    finish();
                }
            }
        });
    }

    private void applySystemBarInsets() {
        ViewCompat.setOnApplyWindowInsetsListener(binding.getRoot(), (view, insets) -> {
            Insets bars = insets.getInsets(WindowInsetsCompat.Type.systemBars());
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
            return insets;
        });
    }

    private void configureNativeUi() {
        binding.toolbar.inflateMenu(R.menu.browser_menu);
        binding.toolbar.setOnMenuItemClickListener(this::handleMenuItem);
        binding.toolbar.setNavigationOnClickListener(view -> goHome());
        binding.addressInput.setOnEditorActionListener((view, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_GO || actionId == EditorInfo.IME_ACTION_SEARCH) {
                submitAddress();
                return true;
            }
            return false;
        });
        binding.goButton.setOnClickListener(view -> submitAddress());
        binding.backButton.setOnClickListener(view -> {
            if (webView != null && webView.canGoBack()) webView.goBack();
        });
        binding.forwardButton.setOnClickListener(view -> {
            if (webView != null && webView.canGoForward()) webView.goForward();
        });
        binding.homeButton.setOnClickListener(view -> goHome());
        binding.reloadButton.setOnClickListener(view -> {
            if (webView != null) webView.reload();
        });
        updateDesktopMenuState();
        updateNavigationState();
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void createWebView(@Nullable Bundle savedState) {
        if (webView != null) {
            binding.webContainer.removeView(webView);
            webView.destroy();
        }

        webView = new WebView(this);
        webView.setLayoutParams(new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        binding.webContainer.removeAllViews();
        binding.webContainer.addView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(false);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setSupportMultipleWindows(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setSafeBrowsingEnabled(true);
        settings.setBuiltInZoomControls(true);
        settings.setDisplayZoomControls(false);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);

        mobileUserAgent = settings.getUserAgentString();
        applyUserAgent();
        CookieManager cookieManager = CookieManager.getInstance();
        cookieManager.setAcceptCookie(true);
        cookieManager.setAcceptThirdPartyCookies(webView, false);
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);

        webView.setWebViewClient(new BrowserClient());
        webView.setWebChromeClient(new BrowserChromeClient());
        webView.setDownloadListener(createDownloadListener());

        boolean restored = savedState != null && webView.restoreState(savedState) != null;
        if (!restored) {
            webView.loadUrl(lastUrl);
        }
    }

    private void applyUserAgent() {
        if (webView == null || mobileUserAgent == null || mobileUserAgent.isEmpty()) {
            return;
        }
        String userAgent = mobileUserAgent;
        if (desktopMode) {
            userAgent = mobileUserAgent
                    .replaceAll("\\(Linux; Android[^)]*\\)", "(X11; Linux x86_64)")
                    .replace(" Mobile ", " ")
                    .replace("; wv", "");
        }
        webView.getSettings().setUserAgentString(userAgent);
    }

    private void submitAddress() {
        String destination = UrlResolver.resolve(
                binding.addressInput.getText() == null ? "" : binding.addressInput.getText().toString());
        hideKeyboard();
        if (UrlResolver.isHttpOrHttps(destination)) {
            webView.loadUrl(destination);
        } else {
            promptExternalUri(Uri.parse(destination));
        }
    }

    private void goHome() {
        if (webView != null) {
            webView.loadUrl(UrlResolver.NEW_TAB_URL);
        }
    }

    private void hideKeyboard() {
        View current = getCurrentFocus();
        if (current == null) current = binding.addressInput;
        InputMethodManager manager = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
        manager.hideSoftInputFromWindow(current.getWindowToken(), 0);
        binding.addressInput.clearFocus();
    }

    private boolean handleMenuItem(android.view.MenuItem item) {
        int id = item.getItemId();
        if (id == R.id.action_new_tab) {
            goHome();
            return true;
        }
        if (id == R.id.action_share) {
            shareCurrentPage();
            return true;
        }
        if (id == R.id.action_find) {
            showFindDialog();
            return true;
        }
        if (id == R.id.action_desktop) {
            desktopMode = !desktopMode;
            applyUserAgent();
            updateDesktopMenuState();
            if (webView != null) webView.reload();
            return true;
        }
        if (id == R.id.action_open_external) {
            if (webView != null && UrlResolver.isHttpOrHttps(webView.getUrl())) {
                launchExternal(Uri.parse(webView.getUrl()));
            }
            return true;
        }
        if (id == R.id.action_clear_data) {
            confirmClearBrowsingData();
            return true;
        }
        if (id == R.id.action_privacy) {
            webView.loadUrl("https://ghosium.com/legal/privacy-policy");
            return true;
        }
        if (id == R.id.action_about) {
            new MaterialAlertDialogBuilder(this)
                    .setTitle(getString(R.string.about_title))
                    .setMessage(getString(R.string.about_message, BuildConfig.VERSION_NAME))
                    .setPositiveButton(android.R.string.ok, null)
                    .show();
            return true;
        }
        return false;
    }

    private void updateDesktopMenuState() {
        android.view.MenuItem item = binding.toolbar.getMenu().findItem(R.id.action_desktop);
        if (item != null) item.setChecked(desktopMode);
    }

    private void shareCurrentPage() {
        if (webView == null || webView.getUrl() == null) return;
        Intent share = new Intent(Intent.ACTION_SEND);
        share.setType("text/plain");
        share.putExtra(Intent.EXTRA_TEXT, webView.getUrl());
        startActivity(Intent.createChooser(share, getString(R.string.share_page)));
    }

    private void showFindDialog() {
        EditText field = new EditText(this);
        field.setSingleLine(true);
        field.setHint(R.string.find_hint);
        int padding = Math.round(24 * getResources().getDisplayMetrics().density);
        FrameLayout container = new FrameLayout(this);
        container.setPadding(padding, 0, padding, 0);
        container.addView(field, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.find_in_page)
                .setView(container)
                .setPositiveButton(R.string.find_action, (dialog, which) -> {
                    if (webView != null) webView.findAllAsync(field.getText().toString());
                })
                .setNegativeButton(android.R.string.cancel, null)
                .show();
    }

    private void confirmClearBrowsingData() {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.clear_data)
                .setMessage(R.string.clear_data_message)
                .setPositiveButton(R.string.clear_action, (dialog, which) -> clearBrowsingData())
                .setNegativeButton(android.R.string.cancel, null)
                .show();
    }

    private void clearBrowsingData() {
        if (webView != null) {
            webView.stopLoading();
            webView.clearCache(true);
            webView.clearHistory();
            webView.clearFormData();
        }
        CookieManager.getInstance().removeAllCookies(null);
        CookieManager.getInstance().flush();
        WebStorage.getInstance().deleteAllData();
        Snackbar.make(binding.getRoot(), R.string.data_cleared, Snackbar.LENGTH_SHORT).show();
        goHome();
    }

    private void updateNavigationState() {
        boolean back = webView != null && webView.canGoBack();
        boolean forward = webView != null && webView.canGoForward();
        binding.backButton.setEnabled(back);
        binding.forwardButton.setEnabled(forward);
    }

    private void setAddressFromUrl(String url) {
        if (url == null || binding.addressInput.hasFocus()) return;
        binding.addressInput.setText(UrlResolver.isNewTab(url) ? "" : url);
    }

    private void promptExternalUri(Uri uri) {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.open_external_title)
                .setMessage(getString(R.string.open_external_message, uri.toString()))
                .setPositiveButton(R.string.open_action, (dialog, which) -> launchExternal(uri))
                .setNegativeButton(android.R.string.cancel, null)
                .show();
    }

    private void launchExternal(Uri uri) {
        try {
            Intent intent;
            if ("intent".equalsIgnoreCase(uri.getScheme())) {
                intent = Intent.parseUri(uri.toString(), Intent.URI_INTENT_SCHEME);
                intent.addCategory(Intent.CATEGORY_BROWSABLE);
                intent.setComponent(null);
                intent.setSelector(null);
            } else {
                intent = new Intent(Intent.ACTION_VIEW, uri);
                intent.addCategory(Intent.CATEGORY_BROWSABLE);
            }
            if (intent.resolveActivity(getPackageManager()) != null) {
                startActivity(intent);
                return;
            }
            String fallback = intent.getStringExtra("browser_fallback_url");
            if (fallback != null && UrlResolver.isHttpOrHttps(fallback)) {
                webView.loadUrl(fallback);
                return;
            }
        } catch (Exception ignored) {
            // Fall through to a user-visible error without crashing the browser.
        }
        Snackbar.make(binding.getRoot(), R.string.no_external_app, Snackbar.LENGTH_LONG).show();
    }

    private DownloadListener createDownloadListener() {
        return (url, userAgent, contentDisposition, mimeType, contentLength) -> {
            if (!UrlResolver.isHttpOrHttps(url)) {
                Snackbar.make(binding.getRoot(), R.string.download_unsupported, Snackbar.LENGTH_LONG).show();
                return;
            }
            try {
                String fileName = URLUtil.guessFileName(url, contentDisposition, mimeType);
                DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
                request.setTitle(fileName);
                request.setDescription(getString(R.string.download_description));
                request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
                request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName);
                if (mimeType != null && !mimeType.isEmpty()) request.setMimeType(mimeType);
                if (userAgent != null && !userAgent.isEmpty()) request.addRequestHeader("User-Agent", userAgent);
                String cookies = CookieManager.getInstance().getCookie(url);
                if (cookies != null && !cookies.isEmpty()) request.addRequestHeader("Cookie", cookies);
                DownloadManager manager = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
                manager.enqueue(request);
                Snackbar.make(binding.getRoot(), getString(R.string.download_started, fileName), Snackbar.LENGTH_LONG).show();
            } catch (Exception error) {
                Snackbar.make(binding.getRoot(), R.string.download_failed, Snackbar.LENGTH_LONG).show();
            }
        };
    }

    private WebResourceResponse assetResponse(Uri uri) {
        String path = uri.getPath();
        if (path == null || !path.startsWith(APP_ASSET_PREFIX)) return null;
        String asset = path.substring(APP_ASSET_PREFIX.length());
        if (!("newtab.html".equals(asset) || "newtab.css".equals(asset))) {
            return notFoundResponse();
        }
        String mime = asset.endsWith(".css") ? "text/css" : "text/html";
        try {
            InputStream input = getAssets().open(asset);
            Map<String, String> headers = new HashMap<>();
            headers.put("Cache-Control", "no-store");
            headers.put("Content-Security-Policy",
                    "default-src 'self'; style-src 'self'; img-src 'self' data:; script-src 'none'; " +
                            "connect-src 'none'; frame-src 'none'; form-action https://www.google.com");
            return new WebResourceResponse(mime, "UTF-8", 200, "OK", headers, input);
        } catch (IOException ignored) {
            return notFoundResponse();
        }
    }

    private WebResourceResponse notFoundResponse() {
        return new WebResourceResponse("text/plain", "UTF-8", 404, "Not Found",
                Collections.emptyMap(), new ByteArrayInputStream(new byte[0]));
    }

    private final class BrowserClient extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            Uri uri = request.getUrl();
            String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
            if ("https".equals(scheme) || "http".equals(scheme)) return false;
            promptExternalUri(uri);
            return true;
        }

        @Nullable
        @Override
        public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
            Uri uri = request.getUrl();
            if ("https".equalsIgnoreCase(uri.getScheme()) && APP_ASSET_HOST.equalsIgnoreCase(uri.getHost())) {
                return assetResponse(uri);
            }
            return super.shouldInterceptRequest(view, request);
        }

        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
            lastUrl = url == null ? lastUrl : url;
            binding.progress.setVisibility(View.VISIBLE);
            setAddressFromUrl(url);
            updateNavigationState();
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            lastUrl = url == null ? lastUrl : url;
            binding.progress.setVisibility(View.GONE);
            setAddressFromUrl(url);
            updateNavigationState();
        }

        @Override
        public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
            if (request.isForMainFrame()) {
                Snackbar.make(binding.getRoot(), R.string.page_load_failed, Snackbar.LENGTH_LONG)
                        .setAction(R.string.reload, v -> view.reload())
                        .show();
            }
        }

        @Override
        public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
            handler.cancel();
            Snackbar.make(binding.getRoot(), R.string.ssl_error, Snackbar.LENGTH_LONG).show();
        }

        @Override
        public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail) {
            String recoveryUrl = lastUrl;
            binding.webContainer.removeView(view);
            view.destroy();
            webView = null;
            lastUrl = recoveryUrl == null ? UrlResolver.NEW_TAB_URL : recoveryUrl;
            createWebView(null);
            Snackbar.make(binding.getRoot(),
                    detail.didCrash() ? R.string.renderer_recovered_crash : R.string.renderer_recovered,
                    Snackbar.LENGTH_LONG).show();
            return true;
        }
    }

    private final class BrowserChromeClient extends WebChromeClient {
        @Override
        public void onProgressChanged(WebView view, int newProgress) {
            binding.progress.setProgressCompat(newProgress, true);
            binding.progress.setVisibility(newProgress >= 100 ? View.GONE : View.VISIBLE);
        }

        @Override
        public void onReceivedTitle(WebView view, String title) {
            binding.toolbar.setSubtitle(title == null || title.isBlank() ? null : title);
        }

        @Override
        public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback,
                                         FileChooserParams fileChooserParams) {
            if (pendingFileChooser != null) pendingFileChooser.onReceiveValue(null);
            pendingFileChooser = filePathCallback;
            Intent intent = fileChooserParams.createIntent();
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            try {
                fileChooserLauncher.launch(intent);
                return true;
            } catch (Exception error) {
                pendingFileChooser = null;
                Snackbar.make(binding.getRoot(), R.string.file_picker_failed, Snackbar.LENGTH_LONG).show();
                return false;
            }
        }

        @Override
        public void onShowCustomView(View view, CustomViewCallback callback) {
            if (customView != null) {
                callback.onCustomViewHidden();
                return;
            }
            customView = view;
            customViewCallback = callback;
            binding.getRoot().setVisibility(View.GONE);
            ViewGroup decor = (ViewGroup) getWindow().getDecorView();
            decor.addView(view, new ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            WindowInsetsControllerCompat controller =
                    WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
            controller.hide(WindowInsetsCompat.Type.systemBars());
            controller.setSystemBarsBehavior(
                    WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        }

        @Override
        public void onHideCustomView() {
            hideCustomView();
        }
    }

    private void hideCustomView() {
        if (customView == null) return;
        ViewGroup parent = (ViewGroup) customView.getParent();
        if (parent != null) parent.removeView(customView);
        customView = null;
        binding.getRoot().setVisibility(View.VISIBLE);
        WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView())
                .show(WindowInsetsCompat.Type.systemBars());
        if (customViewCallback != null) {
            customViewCallback.onCustomViewHidden();
            customViewCallback = null;
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (intent.getData() != null && UrlResolver.isHttpOrHttps(intent.getData().toString())) {
            webView.loadUrl(intent.getData().toString());
        }
    }

    @Override
    protected void onSaveInstanceState(@NonNull Bundle outState) {
        outState.putString(STATE_LAST_URL, lastUrl);
        outState.putBoolean(STATE_DESKTOP, desktopMode);
        if (webView != null) webView.saveState(outState);
        super.onSaveInstanceState(outState);
    }

    @Override
    protected void onDestroy() {
        if (pendingFileChooser != null) {
            pendingFileChooser.onReceiveValue(null);
            pendingFileChooser = null;
        }
        if (webView != null) {
            binding.webContainer.removeView(webView);
            webView.stopLoading();
            webView.setWebChromeClient(null);
            webView.setWebViewClient(null);
            webView.destroy();
            webView = null;
        }
        super.onDestroy();
    }
}
