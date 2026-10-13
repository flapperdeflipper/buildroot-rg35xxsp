/* rgos-youtube-app: windowed YouTube client (GTK3 + yt-dlp + mpv).
 *
 * Search with the on-screen keyboard (it opens by itself for the search
 * box), walk the results with the d-pad, play with A. The pad is put in
 * nav mode for the list and restored when the window closes.
 */
#include <gtk/gtk.h>
#include <string.h>

#define RESULTS 12
#define FORMAT "bv*[height<=480][vcodec^=avc1]+ba/bv*[height<=480][vcodec^=vp9]+ba/b[height<=480]/bv*[height<=480]+ba/b"

typedef struct {
    char *id, *title, *channel, *dur;
} Result;

static GtkEntry *entry;
static GtkListBox *listbox;
static GtkLabel *status;
static Result results[64];
static int nresults;
static char query[256];
static int searching;

void start_search(const char *q, int more);

static void padctl(const char *a, const char *b)
{
    char *argv[] = {(char *)"rgos-padctl", (char *)a, (char *)b, NULL};
    g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH,
                  NULL, NULL, NULL, NULL);
}

static void to_list(void)
{
    padctl("osk", "off");
    padctl("mode", "nav");
    GList *rows = gtk_container_get_children(GTK_CONTAINER(listbox));
    if (rows) {
        gtk_list_box_select_row(listbox, rows->data);
        gtk_widget_grab_focus(rows->data);
    }
}

static void free_results(void)
{
    for (int i = 0; i < nresults; i++) {
        g_free(results[i].id); g_free(results[i].title);
        g_free(results[i].channel); g_free(results[i].dur);
    }
    nresults = 0;
}

static void on_destroy(GtkWidget *w, gpointer data)
{
    (void)w; (void)data;
    padctl("osk", "off");
    padctl("mode", "mouse");
    gtk_main_quit();
}

static gboolean on_key(GtkWidget *w, GdkEventKey *ev, gpointer data)
{
    (void)w; (void)data;
    if (ev->keyval == GDK_KEY_Escape && gtk_widget_has_focus(GTK_WIDGET(entry))) {
        if (nresults > 0) { to_list(); return TRUE; }
    }
    return FALSE;
}

static gboolean on_entry_focus(GtkWidget *w, GdkEvent *ev, gpointer data)
{
    (void)ev; (void)data;
    padctl("osk", "on");
    return FALSE;
}

/* --- play ------------------------------------------------------------- */
static void on_row_activated(GtkListBox *box, GtkListBoxRow *row, gpointer data)
{
    (void)box; (void)data;
    int idx = gtk_list_box_row_get_index(row);
    if (idx < 0 || idx >= nresults) {          /* the More row */
        gtk_label_set_text(status, "Loading more ...");
        start_search(gtk_entry_get_text(entry), TRUE);
        return;
    }
    char url[128];
    g_snprintf(url, sizeof url, "https://www.youtube.com/watch?v=%s", results[idx].id);
    char fmt[256];
    g_snprintf(fmt, sizeof fmt, "--ytdl-format=%s", FORMAT);
    char input_conf[] = "--input-conf=/usr/share/rgos/youtube-input.conf";
    char *argv[] = {(char *)"mpv", (char *)"--fs",
                    (char *)"--force-window=immediate", input_conf, fmt, url, NULL};
    gtk_label_set_text(status, "Playing - close mpv (B) to come back");
    g_spawn_sync(NULL, argv, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_STDOUT_TO_DEV_NULL,
                 NULL, NULL, NULL, NULL, NULL, NULL);
    to_list();
}

/* --- search (in a thread) --------------------------------------------- */
typedef struct {
    int count;
    char *lines;   /* yt-dlp --print output */
    gboolean ok;
} SearchOut;

static gpointer search_thread(gpointer data)
{
    SearchOut *out = data;
    char *spec = g_strdup_printf("ytsearch%d:%s", out->count, query);
    char *argv[] = {(char *)"yt-dlp", (char *)"--no-warnings",
                    (char *)"--flat-playlist", (char *)"--print",
                    (char *)"%(id)s\t%(title)s\t%(channel)s\t%(duration_string)s",
                    spec, NULL};
    out->ok = g_spawn_sync(NULL, argv, NULL, G_SPAWN_SEARCH_PATH,
                           NULL, NULL, &out->lines, NULL, NULL, NULL);
    g_free(spec);
    return NULL;
}

static gboolean populate(gpointer data)
{
    SearchOut *out = data;
    GList *children = gtk_container_get_children(GTK_CONTAINER(listbox));
    for (GList *c = children; c; c = c->next) gtk_widget_destroy(c->data);
    g_list_free(children);
    free_results();

    if (out->ok && out->lines) {
        gchar **rows = g_strsplit(out->lines, "\n", 0);
        for (int i = 0; rows[i] && rows[i][0] && nresults < 64; i++) {
            gchar **f = g_strsplit(rows[i], "\t", 4);
            if (!f[0] || !f[1]) { g_strfreev(f); continue; }
            results[nresults++] = (Result){ g_strdup(f[0]), g_strdup(f[1]),
                                            g_strdup(f[2] ? f[2] : ""),
                                            g_strdup(f[3] ? f[3] : "") };
            g_strfreev(f);
        }
        g_strfreev(rows);
    }
    for (int i = 0; i < nresults; i++) {
        GtkWidget *rowbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
        gtk_widget_set_margin_top(rowbox, 5); gtk_widget_set_margin_bottom(rowbox, 5);
        gtk_widget_set_margin_start(rowbox, 6); gtk_widget_set_margin_end(rowbox, 6);
        GtkWidget *t = gtk_label_new(results[i].title);
        gtk_label_set_line_wrap(GTK_LABEL(t), TRUE);
        gtk_label_set_xalign(GTK_LABEL(t), 0.0);
        gtk_widget_set_halign(t, GTK_ALIGN_START);
        gtk_box_pack_start(GTK_BOX(rowbox), t, TRUE, TRUE, 0);
        char sub[256];
        g_snprintf(sub, sizeof sub, "%s  -  %s",
                   results[i].channel[0] ? results[i].channel : "?",
                   results[i].dur[0] ? results[i].dur : "live");
        GtkWidget *s = gtk_label_new(sub);
        gtk_widget_set_halign(s, GTK_ALIGN_START);
        gtk_label_set_xalign(GTK_LABEL(s), 0.0);
        gtk_widget_set_opacity(s, 0.6);
        gtk_box_pack_start(GTK_BOX(rowbox), s, FALSE, FALSE, 0);
        gtk_list_box_insert(listbox, rowbox, -1);
    }
    gtk_list_box_insert(listbox, gtk_label_new("More ..."), -1);
    gtk_widget_show_all(GTK_WIDGET(listbox));
    gtk_label_set_text(status, nresults ? "d-pad walks, A plays" : "No results");
    searching = 0;
    to_list();
    g_free(out->lines); g_free(out);
    return FALSE;
}

void start_search(const char *q, int more)
{
    if (searching) return;
    g_strlcpy(query, q, sizeof query);
    if (!query[0]) return;
    searching = 1;
    gtk_label_set_text(status, more ? "Loading more ..." : "Searching ...");
    SearchOut *out = g_new0(SearchOut, 1);
    out->count = more ? RESULTS * 2 : RESULTS;   /* more = bigger page */
    g_thread_unref(g_thread_new("ytsearch", search_thread, out));
}

static void on_search(GtkWidget *w, gpointer data)
{
    (void)w; (void)data;
    start_search(gtk_entry_get_text(entry), FALSE);
}

int main(int argc, char **argv)
{
    gtk_init(&argc, &argv);

    GtkWidget *win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(win), "YouTube");
    gtk_window_set_default_size(GTK_WINDOW(win), 600, 440);
    g_signal_connect(win, "destroy", G_CALLBACK(on_destroy), NULL);
    g_signal_connect(win, "key-press-event", G_CALLBACK(on_key), NULL);

    GtkWidget *top = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    entry = GTK_ENTRY(gtk_entry_new());
    gtk_entry_set_placeholder_text(entry, "Search YouTube");
    g_signal_connect(entry, "activate", G_CALLBACK(on_search), NULL);
    g_signal_connect(entry, "focus-in-event", G_CALLBACK(on_entry_focus), NULL);
    GtkWidget *btn = gtk_button_new_with_label("Search");
    g_signal_connect(btn, "clicked", G_CALLBACK(on_search), NULL);
    gtk_box_pack_start(GTK_BOX(top), GTK_WIDGET(entry), TRUE, TRUE, 6);
    gtk_box_pack_start(GTK_BOX(top), btn, FALSE, FALSE, 6);

    GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll),
                                   GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    listbox = GTK_LIST_BOX(gtk_list_box_new());
    g_signal_connect(listbox, "row-activated", G_CALLBACK(on_row_activated), NULL);
    gtk_container_add(GTK_CONTAINER(scroll), GTK_WIDGET(listbox));

    status = GTK_LABEL(gtk_label_new(""));
    gtk_widget_set_halign(GTK_WIDGET(status), GTK_ALIGN_START);
    gtk_label_set_xalign(status, 0.0);

    GtkWidget *col = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    gtk_box_pack_start(GTK_BOX(col), top, FALSE, FALSE, 6);
    gtk_box_pack_start(GTK_BOX(col), scroll, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(col), GTK_WIDGET(status), FALSE, FALSE, 4);
    gtk_container_add(GTK_CONTAINER(win), col);

    gtk_widget_show_all(win);
    if (argc > 1 && argv[1][0]) {
        gtk_entry_set_text(entry, argv[1]);
        start_search(argv[1], FALSE);
    } else {
        gtk_widget_grab_focus(GTK_WIDGET(entry));
    }
    gtk_main();
    return 0;
}
