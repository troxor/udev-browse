using Udev;
using Gtk;
using GLib;
using Pango;
using Gee;
using Gnu;

public class LeftLabel : Label {
        public LeftLabel(string? text = null) {
                if (text != null)
                        set_markup("<b>%s</b>".printf(text));
                set_alignment(1, 0);
                set_padding(6, 0);
        }
}

public class RightLabel : Label {
        public RightLabel(string? text = null) {
                set_text_or_na(text);
                set_alignment(0, 1);
                set_ellipsize(EllipsizeMode.START);
                set_selectable(true);
        }

        public void set_text_or_na(string? text = null) {
                if (text == null)
                        set_markup("<i>n/a</i>");
                else
                        set_text(text);
        }
}

public class MainWindow : Window {
        private Udev.Client client;

        private TreeView device_view;
        private TreeView property_view;

        private TreeStore device_model;
        private ListStore property_model;

        private RightLabel name_label;
        private RightLabel subsystem_label;
        private RightLabel sysfs_path_label;
        private RightLabel parent_sysfs_path_label;
        private RightLabel devtype_label;
        private RightLabel driver_label;
        private RightLabel device_file_label;
        private RightLabel device_file_symlinks_label;
        private RightLabel number_label;
        private RightLabel seqnum_label;

        private LinkButton parent_button;

        private CheckButton follow_add_check_button;
        private CheckButton follow_change_check_button;

        private HashMap<string,TreeRowReference> rows;
        private HashMap<string,uint64?> seqnums;

        public MainWindow() {
                string ss[1];

                title = "udev Browser";
                position = WindowPosition.CENTER;
                set_default_size(1000, 700);
                set_border_width(12);

                destroy.connect(Gtk.main_quit);

                rows = new HashMap<string, TreeRowReference>();
                seqnums = new HashMap<string, uint64?>();

                ss[0] = null;
                client = new Udev.Client(ss);

                client.uevent.connect(uevent);

                device_model = new TreeStore(3, typeof(string), typeof(string), typeof(string));
                property_model = new ListStore(2, typeof(string), typeof(string));

                device_view = new TreeView.with_model(device_model);
                property_view = new TreeView.with_model(property_model);

                device_view.cursor_changed.connect(device_changed);
                device_view.set_enable_tree_lines(true);

                device_view.insert_column_with_attributes (-1, "Device", new CellRendererText(), "text", 0);
                device_view.insert_column_with_attributes (-1, "Subsystem", new CellRendererText(), "text", 2);
                property_view.insert_column_with_attributes (-1, "Property", new CellRendererText(), "text", 0);
                property_view.insert_column_with_attributes (-1, "Value", new CellRendererText(), "text", 1);

                Paned hpaned = new HPaned();
                add(hpaned);

                ScrolledWindow scroll = new ScrolledWindow(null, null);
                scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
                scroll.set_shadow_type(ShadowType.IN);
                scroll.add(device_view);
                hpaned.pack1(scroll, true, false);

                Box vbox = new VBox(false, 6);
                hpaned.pack2(vbox, true, false);

                Table table = new Table(11, 2, false);
                table.set_row_spacings(6);
                vbox.pack_start(table, false, false, 0);

                name_label = new RightLabel();
                subsystem_label = new RightLabel();
                sysfs_path_label = new RightLabel();
                parent_sysfs_path_label = new RightLabel();
                devtype_label = new RightLabel();
                driver_label = new RightLabel();
                device_file_label = new RightLabel();
                device_file_symlinks_label = new RightLabel();
                number_label = new RightLabel();
                seqnum_label = new RightLabel();

                table.attach(new LeftLabel("Name:"), 0, 1, 0, 1, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(name_label, 1, 2, 0, 1, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(new LeftLabel("Subsystem:"), 0, 1, 1, 2, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(subsystem_label, 1, 2, 1, 2, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(new LeftLabel("Sysfs Path:"), 0, 1, 2, 3, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(sysfs_path_label, 1, 2, 2, 3, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(new LeftLabel("Parent Sysfs Path:"), 0, 1, 3, 4, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(parent_sysfs_path_label, 1, 2, 3, 4, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(new LeftLabel("Device Type:"), 0, 1, 4, 5, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(devtype_label, 1, 2, 4, 5, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(new LeftLabel("Driver:"), 0, 1, 5, 6, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(driver_label, 1, 2, 5, 6, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(new LeftLabel("Device File:"), 0, 1, 6, 7, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(device_file_label, 1, 2, 6, 7, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(new LeftLabel("Device File Symbolic Link(s):"), 0, 1, 7, 8, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(device_file_symlinks_label, 1, 2, 7, 8, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(new LeftLabel("Number:"), 0, 1, 8, 9, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(number_label, 1, 2, 8, 9, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(new LeftLabel("Sequence Number:"), 0, 1, 9, 10, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                table.attach(seqnum_label, 1, 2, 9, 10, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);

                parent_button = new LinkButton.with_label("", "Go To parent");
                table.attach(parent_button, 0, 2, 10, 11, 0, 0, 0, 0);

                scroll = new ScrolledWindow(null, null);
                scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
                scroll.set_shadow_type(ShadowType.IN);
                scroll.add(property_view);
                vbox.pack_start(scroll, true, true, 0);

                follow_change_check_button = new CheckButton.with_mnemonic("Focus follows changing devices");
                follow_add_check_button = new CheckButton.with_mnemonic("Focus follows new devices");
                follow_add_check_button.set_active(true);
                vbox.pack_start(follow_add_check_button, false, false, 0);
                vbox.pack_start(follow_change_check_button, false, false, 0);

                parent_button.clicked.connect(go_to_parent);

                add_all_devices();
        }

        public void add_device(Device d) {
                string sysfs = d.get_sysfs_path();
                Device p = d.get_parent();
                TreeIter i;

                if (p == null)
                        device_model.append(out i, null);
                else {
                        string psysfs = p.get_sysfs_path();

                        if (psysfs in rows) {
                                TreeIter pi;

                                device_model.get_iter(out pi, rows[psysfs].get_path());
                                device_model.append(out i, pi);
                        } else
                                device_model.append(out i, null);
                }

                device_model.set(i, 0, d.get_name(), 1, sysfs, 2, d.get_subsystem());
                rows[sysfs] = new TreeRowReference(device_model, device_model.get_path(i));

                uint64 sn = d.get_seqnum();
                if (sn != 0)
                        seqnums[sysfs] = sn;
        }

        public void remove_device(Device d) {
                string sysfs = d.get_sysfs_path();

                if (!(sysfs in rows))
                        return;

                TreeIter i;
                device_model.get_iter(out i, rows[sysfs].get_path());
                device_model.remove(i);

                rows.remove(sysfs);
                seqnums.remove(sysfs);
        }

        public void add_all_devices() {
                foreach (Device d in client.query_by_subsystem())
                        add_device(d);

                device_view.expand_all();
        }

        public Device? get_current_device() {
                TreePath p;
                TreeIter iter;
                string sysfs;

                device_view.get_cursor(out p, null);

                if (p == null)
                        return null;

                device_model.get_iter(out iter, p);
                device_model.get(iter, 1, out sysfs);

                return client.query_by_sysfs_path(sysfs);
        }

        public void set_current_device(Device? d) {
                string sysfs = d.get_sysfs_path();

                if (sysfs in rows)
                        device_view.set_cursor(rows[sysfs].get_path(), null, false);
        }

        public Device lookup_sysfs(string sysfs) {
                Device d = client.query_by_sysfs_path(sysfs);

                if (d == null) {
                        string t = canonicalize_file_name(sysfs);

                        if (t != null)
                                d = client.query_by_sysfs_path(t);
                }

                return d;
        }

        public void set_current_device_by_sysfs_path(string? sysfs) {
                Device d;

                if (sysfs == null)
                        d = lookup_sysfs(Environment.get_current_dir());
                else {
                        d = lookup_sysfs(sysfs);

                        if (d == null)
                                d = lookup_sysfs(Path.build_filename(Environment.get_current_dir(), sysfs));

                        if (d == null)
                        d = lookup_sysfs(Path.build_filename("/sys/", sysfs));
                }

                if (d != null)
                        set_current_device(d);
        }

        public void device_changed() {
                Device d;

                d = get_current_device();

                if (d == null)
                        device_clear();
                else
                        device_update(d);
        }

        public void go_to_parent() {
                Device d = get_current_device();

                if (d != null) {
                        Device p = d.get_parent();

                        if (p != null)
                                set_current_device(p);
                }
        }

        public void device_clear() {
                name_label.set_text_or_na();
                subsystem_label.set_text_or_na();
                sysfs_path_label.set_text_or_na();
                parent_sysfs_path_label.set_text_or_na();
                devtype_label.set_text_or_na();
                driver_label.set_text_or_na();
                device_file_label.set_text_or_na();
                device_file_symlinks_label.set_text_or_na();
                number_label.set_text_or_na();
                seqnum_label.set_text_or_na();

                property_model.clear();

                parent_button.set_sensitive(false);
                parent_button.set_uri("n/a");
        }

        public void device_update(Device d) {

                string sysfs = d.get_sysfs_path();

                name_label.set_text_or_na(d.get_name());
                subsystem_label.set_text_or_na(d.get_subsystem());
                sysfs_path_label.set_text_or_na(sysfs);
                devtype_label.set_text_or_na(d.get_devtype());
                driver_label.set_text_or_na(d.get_driver());
                device_file_label.set_text_or_na(d.get_device_file());
                number_label.set_text_or_na(d.get_number());

                property_model.clear();
                foreach (var k in d.get_property_keys()) {
                        TreeIter iter;
                        property_model.append (out iter);
                        property_model.set(iter, 0, k);
                        var v = d.get_property(k);
                        property_model.set(iter, 1, v == null ? "n/a" : v);
                }

                Device p = d.get_parent();
                if (p == null) {
                        parent_button.set_sensitive(false);
                        parent_button.set_uri("n/a");
                        parent_sysfs_path_label.set_text_or_na();
                } else {
                        string psysfs = p.get_sysfs_path();

                        parent_button.set_sensitive(psysfs in rows);
                        parent_button.set_uri(psysfs);
                        parent_sysfs_path_label.set_text_or_na(psysfs);
                }

                if (sysfs in seqnums)
                        seqnum_label.set_text_or_na("%llu".printf(seqnums[sysfs]));
                else
                        seqnum_label.set_text_or_na();

                var l = d.get_device_file_symlinks();
                if (l != null && l.length > 0)
                        device_file_symlinks_label.set_text_or_na(string.joinv("\n", l));
                else
                        device_file_symlinks_label.set_text_or_na();

        }

        public void uevent(string action, Device d) {
                string sysfs = d.get_sysfs_path();

                if (action == "remove") {
                        remove_device(d);

                        Device current = get_current_device();
                        if (current == null || current.get_sysfs_path() == d.get_sysfs_path())
                                device_clear();

                } else if (action == "add") {
                        add_device(d);
                        device_view.expand_all();
                }

                if (sysfs in rows) {
                        seqnums[sysfs] = d.get_seqnum();

                        if ((action == "change" && follow_change_check_button.get_active()) ||
                            (action == "add" && follow_add_check_button.get_active()))
                                set_current_device(d);

                        else if (action == "change") {
                                Device current = get_current_device();
                                if (current != null && current.get_sysfs_path() == d.get_sysfs_path())
                                        device_update(current);
                        }
                }
        }

        public void scroll_to_cursor() {
                TreePath p;

                device_view.get_cursor(out p, null);
                device_view.scroll_to_cell(p, null, true, 0.5f, 0);
        }
}

void uri_hook(LinkButton button, string uri) {
        /* nop */
}

int main (string[] args) {
    Gtk.init(ref args);
    LinkButton.set_uri_hook(uri_hook);

    MainWindow window = new MainWindow();
    window.set_current_device_by_sysfs_path(args.length > 1 ? args[1] : null);
    window.show_all();
    window.scroll_to_cursor();

    Gtk.main ();
    return 0;
}