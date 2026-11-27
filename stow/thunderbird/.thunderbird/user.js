// Shared preferences only. Accounts and saved logins come from secrets.toml.
// Thunderbird reads a link to this file inside the selected profile at startup.

// Suppress the outgoing email User-Agent header, not the HTTP user agent.
user_pref("mailnews.headers.sendUserAgent", false);

// Follow the system theme and timezone.
user_pref("extensions.activeThemeID", "default-theme@mozilla.org");
user_pref("browser.theme.content-theme", 0);
user_pref("browser.theme.toolbar-theme", 0);
user_pref("calendar.timezone.useSystemTimezone", true);

user_pref("mail.shell.checkDefaultClient", false);
user_pref("mail.warn_on_send_accel_key", false);
