package dev.idfixture.qa.share_receiver;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Process;
import android.provider.MediaStore;
import android.provider.OpenableColumns;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Locale;

/**
 * Test fixture only. The OS grants one content URI when the user selects this
 * activity from Sharesheet. No root, source app private-path access, networking,
 * persistable grant, or dangerous storage permission is used.
 */
public final class ShareReceiverActivity extends Activity {
    private static final String EXPECTED_AUTHORITY =
        "dev.idfixture.id_fixture.flutter.share_provider";
    private static final int MAX_BYTES = 1024 * 1024;
    private TextView status;
    private Button done;
    private volatile boolean destroyed;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        buildView();
        final Intent incoming = getIntent();
        new Thread(() -> receive(incoming), "IDFixture-QA-local-copy").start();
    }

    private void buildView() {
        final int pad = (int) (20 * getResources().getDisplayMetrics().density);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(pad, pad, pad, pad);
        content.setBackgroundColor(Color.rgb(246, 247, 245));
        TextView title = new TextView(this);
        title.setText("ID Fixture QA Receiver");
        title.setTextSize(23);
        title.setTextColor(Color.rgb(26, 80, 68));
        content.addView(title);
        TextView boundary = new TextView(this);
        boundary.setText("仅本机验收夹具 · 不随产品发布\nLocal QA fixture · Not part of the product\n");
        boundary.setTextSize(14);
        boundary.setTextColor(Color.DKGRAY);
        content.addView(boundary);
        status = new TextView(this);
        status.setText("正在检查共享URI授权并保存原始字节…\nChecking granted URI and saving original bytes…");
        status.setTextSize(15);
        status.setTextIsSelectable(true);
        status.setTextColor(Color.rgb(35, 43, 39));
        content.addView(status);
        done = new Button(this);
        done.setText("完成并返回 / Done");
        done.setEnabled(false);
        done.setOnClickListener(v -> finish());
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT);
        buttonParams.topMargin = pad;
        content.addView(done, buttonParams);
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.addView(content);
        setContentView(scroll);
    }

    private void receive(Intent incoming) {
        Uri destination = null;
        ContentResolver resolver = getContentResolver();
        try {
            if (!Intent.ACTION_SEND.equals(incoming.getAction())
                    || !"application/json".equals(incoming.getType())) {
                throw new IllegalArgumentException("只接收ACTION_SEND application/json / Unsupported share action or MIME type");
            }
            Uri source = incoming.getParcelableExtra(Intent.EXTRA_STREAM);
            if (source == null || !"content".equals(source.getScheme())
                    || !EXPECTED_AUTHORITY.equals(source.getAuthority())) {
                throw new SecurityException("只接收本任务产品FileProvider的content URI / Unexpected content authority");
            }
            boolean hasReadFlag = (incoming.getFlags()
                & Intent.FLAG_GRANT_READ_URI_PERMISSION) != 0;
            int permission = checkUriPermission(source, Process.myPid(),
                Process.myUid(), Intent.FLAG_GRANT_READ_URI_PERMISSION);
            if (!hasReadFlag || permission != PackageManager.PERMISSION_GRANTED) {
                throw new SecurityException("系统未授予读取该URI的权限 / Missing OS read grant");
            }
            String filename = displayName(resolver, source);
            if (filename == null
                    || !filename.matches("(?i)[a-z0-9._-]{1,175}\\.json")) {
                throw new IllegalArgumentException("共享文件名不是预期的安全JSON名称 / Unexpected JSON display name");
            }
            byte[] original;
            try (InputStream stream = resolver.openInputStream(source)) {
                original = readBounded(stream);
            }
            if (original.length == 0) {
                throw new IllegalArgumentException("共享文件为空 / Empty shared file");
            }
            String digest = sha256(original);
            String session = "receive-" + System.currentTimeMillis()
                + "-" + Long.toHexString(System.nanoTime());
            // A unique subdirectory preserves the original JSON basename
            // without overwriting an earlier QA capture or accepting suffixes.
            String relativePath = Environment.DIRECTORY_DOWNLOADS
                + "/IDFixture-QA/" + session + "/";
            ContentValues values = new ContentValues();
            values.put(MediaStore.Downloads.DISPLAY_NAME, filename);
            values.put(MediaStore.Downloads.MIME_TYPE, "application/json");
            values.put(MediaStore.Downloads.RELATIVE_PATH, relativePath);
            values.put(MediaStore.Downloads.IS_PENDING, 1);
            destination = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
            if (destination == null) {
                throw new IllegalStateException("无法创建Downloads记录 / Could not create Downloads item");
            }
            try (OutputStream output = resolver.openOutputStream(destination, "w")) {
                if (output == null) throw new IllegalStateException("无法写入目标 / Cannot open output");
                output.write(original);
                output.flush();
            }
            byte[] readback;
            try (InputStream input = resolver.openInputStream(destination)) {
                readback = readBounded(input);
            }
            if (!Arrays.equals(original, readback)
                    || !digest.equals(sha256(readback))) {
                throw new IllegalStateException("读回字节与原始共享内容不同 / Readback differs from original bytes");
            }
            String actualName = displayName(resolver, destination);
            if (!filename.equals(actualName)) {
                throw new IllegalStateException("目标文件名未保留 / Output display name changed");
            }
            ContentValues publish = new ContentValues();
            publish.put(MediaStore.Downloads.IS_PENDING, 0);
            if (resolver.update(destination, publish, null, null) != 1) {
                throw new IllegalStateException("无法发布Downloads文件 / Cannot publish Downloads item");
            }
            String message = "保存成功 / Saved locally\n\n"
                + "系统临时READ授权 / Transient OS read grant: GRANTED\n"
                + "来源 authority: " + source.getAuthority() + "\n\n"
                + "原文件名 / Original name:\n" + filename + "\n\n"
                + "字节数 / Bytes: " + original.length + "\n\n"
                + "SHA-256:\n" + digest + "\n\n"
                + "原始字节读回一致 / Exact-byte readback: YES\n\n"
                + "保存位置 / Location:\n" + relativePath + filename + "\n\n"
                + "MediaStore URI:\n" + destination + "\n\n"
                + "无网络、无存储危险权限、无root、未访问产品私有路径。\n"
                + "No network/storage permission, root, or source private-path access.";
            showResult(message, true);
        } catch (Exception error) {
            // Only the new row owned by this invocation may be removed.
            if (destination != null) {
                try { resolver.delete(destination, null, null); }
                catch (Exception ignored) { /* Keep the original failure. */ }
            }
            showResult("未保存 / Not saved\n\n" + error.getClass().getSimpleName()
                + ": " + error.getMessage()
                + "\n\n不会绕过URI授权或读取来源应用私有文件。\n"
                + "No grant bypass or private-file fallback.", false);
        }
    }

    private static String displayName(ContentResolver resolver, Uri uri) {
        try (Cursor cursor = resolver.query(uri,
                new String[] { OpenableColumns.DISPLAY_NAME }, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) return cursor.getString(0);
            return null;
        }
    }

    private static byte[] readBounded(InputStream input) throws Exception {
        if (input == null) throw new IllegalStateException("无法打开输入 / Cannot open input");
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int count;
        while ((count = input.read(buffer)) != -1) {
            if (output.size() + count > MAX_BYTES) {
                throw new IllegalArgumentException("文件超过1MB / File exceeds 1 MB");
            }
            output.write(buffer, 0, count);
        }
        return output.toByteArray();
    }

    private static String sha256(byte[] bytes) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
        StringBuilder result = new StringBuilder(64);
        for (byte value : digest) {
            result.append(String.format(Locale.ROOT, "%02x", value & 0xff));
        }
        return result.toString();
    }

    private void showResult(String message, boolean success) {
        runOnUiThread(() -> {
            if (destroyed) return;
            status.setText(message);
            status.setTextColor(success ? Color.rgb(26, 80, 68) : Color.rgb(150, 35, 30));
            done.setEnabled(true);
        });
    }

    @Override
    protected void onDestroy() {
        destroyed = true;
        super.onDestroy();
    }
}
