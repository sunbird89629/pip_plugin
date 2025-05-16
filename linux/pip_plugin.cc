#include "include/pip_plugin/pip_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <cairo.h>
#include <string>

#include "pip_plugin_private.h"

#define PIP_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), pip_plugin_get_type(), \
                              PipPlugin))

struct _PipPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(PipPlugin, pip_plugin, g_object_get_type())

enum TextAlign { ALIGN_LEFT, ALIGN_CENTER, ALIGN_RIGHT };

struct PipWindow {
  GtkWidget* window;
  GtkWidget* drawing_area;
  GtkWidget* menu_bar;
  std::string current_text;
  GdkRGBA bg_color;
  GdkRGBA text_color;
  TextAlign     text_align;
  double text_size; 
  FlMethodChannel* method_channel;
};

static PipWindow* pip_instance = nullptr;

// Cairo drawing callback
static gboolean draw_callback(GtkWidget *widget, cairo_t *cr, gpointer data) {
  PipWindow* pip = static_cast<PipWindow*>(data);

  // Draw background
  cairo_set_source_rgba(cr,
                      pip->bg_color.red,
                      pip->bg_color.green,
                      pip->bg_color.blue,
                      pip->bg_color.alpha);
  cairo_paint(cr);

  // Draw text
  cairo_set_source_rgba(cr,
    pip->text_color.red,
    pip->text_color.green,
    pip->text_color.blue,
    pip->text_color.alpha);
  cairo_select_font_face(cr, "Monospace", CAIRO_FONT_SLANT_NORMAL,
                      CAIRO_FONT_WEIGHT_BOLD);
  cairo_set_font_size(cr, pip->text_size);

  cairo_text_extents_t extents;
  cairo_text_extents(cr, pip->current_text.c_str(), &extents);
  int w = gtk_widget_get_allocated_width(widget);
  int h = gtk_widget_get_allocated_height(widget);

  // 4) Pick X based on alignment
  double x;
  switch (pip->text_align) {
    case ALIGN_LEFT:
      x = 10;  // left + padding
      break;
    case ALIGN_RIGHT:
      x = w - extents.width - 10;
      break;
    case ALIGN_CENTER:
    default:
      x = (w - extents.width) / 2;
  }

  // 5) Vertically center
  double y = (h + extents.height) / 2;

  // 6) Draw
  cairo_move_to(cr, x, y);
  cairo_show_text(cr, pip->current_text.c_str());

  return FALSE;
}

// Create menu bar
static GtkWidget* create_menu_bar() {
  GtkWidget* menu_bar = gtk_menu_bar_new();
  return menu_bar;
}

// Handler for window close event
static gboolean on_window_close(GtkWidget* widget, GdkEvent* event, gpointer data) {
  PipWindow* pip = static_cast<PipWindow*>(data);
  
  // Notify Flutter that PiP was closed
  if (pip->method_channel != nullptr) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    fl_method_channel_invoke_method(pip->method_channel, "pipStopped", result, nullptr, nullptr, nullptr);
  }
  
  // Hide window instead of destroying it
  gtk_widget_hide(widget);
  
  // Return TRUE to prevent the window from being destroyed automatically
  return TRUE;
}

FlMethodResponse* setup_pip(FlValue* args, FlMethodChannel* method_channel) {
  if (!pip_instance) {
    pip_instance = new PipWindow();
    pip_instance->method_channel = method_channel;
    
    // Create main window
    pip_instance->window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(pip_instance->window), "PiP Window");
    gtk_window_set_default_size(GTK_WINDOW(pip_instance->window), 320, 240);
    gtk_window_set_keep_above(GTK_WINDOW(pip_instance->window), TRUE);
    
    // Connect the delete-event signal to handle window close
    g_signal_connect(pip_instance->window, "delete-event", 
        G_CALLBACK(on_window_close), pip_instance);
    
    // Create container
    GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    
    // Add menu bar
    pip_instance->menu_bar = create_menu_bar();
    gtk_box_pack_start(GTK_BOX(box), pip_instance->menu_bar, FALSE, FALSE, 0);
    
    // Add drawing area
    pip_instance->drawing_area = gtk_drawing_area_new();
    gtk_box_pack_start(GTK_BOX(box), pip_instance->drawing_area, TRUE, TRUE, 0);
    g_signal_connect(pip_instance->drawing_area, "draw", 
        G_CALLBACK(draw_callback), pip_instance);
    
    gtk_container_add(GTK_CONTAINER(pip_instance->window), box);
    
    // Default background color (black with 80% opacity)
    pip_instance->bg_color = {0, 0, 0, 0.8};

    pip_instance->text_color = {1, 1, 1, 1.0};

    pip_instance->text_size = 32.0;
    
    // Get parameters
    if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* window_title = fl_value_lookup_string(args, "windowTitle");
      if (window_title != nullptr && fl_value_get_type(window_title) == FL_VALUE_TYPE_STRING) {
        gtk_window_set_title(GTK_WINDOW(pip_instance->window), fl_value_get_string(window_title));
      }

      // Set text
      FlValue* text_value = fl_value_lookup_string(args, "text");
      if (text_value != nullptr && fl_value_get_type(text_value) == FL_VALUE_TYPE_STRING) {
        pip_instance->current_text = fl_value_get_string(text_value);
      }
      
      // Set background color if provided
      FlValue* bg_color = fl_value_lookup_string(args, "backgroundColor");
      if (bg_color != nullptr && fl_value_get_type(bg_color) == FL_VALUE_TYPE_LIST) {
        int r = fl_value_get_int(fl_value_get_list_value(bg_color, 0));
        int g = fl_value_get_int(fl_value_get_list_value(bg_color, 1));
        int b = fl_value_get_int(fl_value_get_list_value(bg_color, 2));
        int a = 255;
        if (fl_value_get_length(bg_color) > 3) {
          a = fl_value_get_int(fl_value_get_list_value(bg_color, 3));
        }
        
        pip_instance->bg_color.red = r / 255.0;
        pip_instance->bg_color.green = g / 255.0;
        pip_instance->bg_color.blue = b / 255.0;
        pip_instance->bg_color.alpha = a / 255.0;
      }

      FlValue* fg_list = fl_value_lookup_string(args, "textColor");
    if (fg_list && fl_value_get_type(fg_list) == FL_VALUE_TYPE_LIST
        && fl_value_get_length(fg_list) >= 4) {
      int r = fl_value_get_int(fl_value_get_list_value(fg_list, 0));
      int g = fl_value_get_int(fl_value_get_list_value(fg_list, 1));
      int b = fl_value_get_int(fl_value_get_list_value(fg_list, 2));
      int a = fl_value_get_int(fl_value_get_list_value(fg_list, 3));
      pip_instance->text_color.red   = r / 255.0;
      pip_instance->text_color.green = g / 255.0;
      pip_instance->text_color.blue  = b / 255.0;
      pip_instance->text_color.alpha = a / 255.0;
    }

    // Text alignment
    FlValue* al = fl_value_lookup_string(args, "textAlign");

if (al && fl_value_get_type(al) == FL_VALUE_TYPE_STRING) {
  const char* s = fl_value_get_string(al);

  if (strcmp(s, "left") == 0) {
    pip_instance->text_align = ALIGN_LEFT;
  } else if (strcmp(s, "right") == 0) {
    pip_instance->text_align = ALIGN_RIGHT;
  } else {
    pip_instance->text_align = ALIGN_CENTER;
  }
}

    // Font size
    FlValue* size_val = fl_value_lookup_string(args, "textSize");
    if (size_val && fl_value_get_type(size_val) == FL_VALUE_TYPE_FLOAT) {
      pip_instance->text_size = fl_value_get_float(size_val);
    }
      
      // Set ratio if provided
      FlValue* ratio = fl_value_lookup_string(args, "ratio");
      if (ratio != nullptr && fl_value_get_type(ratio) == FL_VALUE_TYPE_LIST &&
          fl_value_get_length(ratio) >= 2) {
        int r1 = fl_value_get_int(fl_value_get_list_value(ratio, 0));
        int r2 = fl_value_get_int(fl_value_get_list_value(ratio, 1));
        if (r1 > 0 && r2 > 0) {
          int height = 180;
          int width = height * r1 / r2;          
          gtk_window_set_default_size(GTK_WINDOW(pip_instance->window), width, height);
        }
      }
    }
    
    // Window controls
    gtk_window_set_deletable(GTK_WINDOW(pip_instance->window), TRUE);
    gtk_window_set_resizable(GTK_WINDOW(pip_instance->window), TRUE);
    gtk_window_set_skip_taskbar_hint(GTK_WINDOW(pip_instance->window), FALSE);
  }
  
  g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* update_pip(FlValue* args) {
  if (!pip_instance || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    auto result = fl_value_new_bool(FALSE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  

  // 2) Update background color if provided
  FlValue* bg_list = fl_value_lookup_string(args, "backgroundColor");
  if (bg_list && fl_value_get_type(bg_list) == FL_VALUE_TYPE_LIST
      && fl_value_get_length(bg_list) >= 4) {
    int r = fl_value_get_int(fl_value_get_list_value(bg_list, 0));
    int g = fl_value_get_int(fl_value_get_list_value(bg_list, 1));
    int b = fl_value_get_int(fl_value_get_list_value(bg_list, 2));
    int a = fl_value_get_int(fl_value_get_list_value(bg_list, 3));
    pip_instance->bg_color.red   = r / 255.0;
    pip_instance->bg_color.green = g / 255.0;
    pip_instance->bg_color.blue  = b / 255.0;
    pip_instance->bg_color.alpha = a / 255.0;
  }

  FlValue* fg_list = fl_value_lookup_string(args, "textColor");
  GdkRGBA fg = pip_instance->bg_color;
  if (fg_list && fl_value_get_type(fg_list) == FL_VALUE_TYPE_LIST
      && fl_value_get_length(fg_list) >= 4) {
    int r = fl_value_get_int(fl_value_get_list_value(fg_list, 0));
    int g = fl_value_get_int(fl_value_get_list_value(fg_list, 1));
    int b = fl_value_get_int(fl_value_get_list_value(fg_list, 2));
    int a = fl_value_get_int(fl_value_get_list_value(fg_list, 3));
    fg.red   = r / 255.0;
    fg.green = g / 255.0;
    fg.blue  = b / 255.0;
    fg.alpha = a / 255.0;
  }
  pip_instance->text_color = fg;  

  FlValue* size_val = fl_value_lookup_string(args, "textSize");
  if (size_val && fl_value_get_type(size_val) == FL_VALUE_TYPE_FLOAT) {
    pip_instance->text_size = fl_value_get_float(size_val);
  }

  // Text alignment
  FlValue* al = fl_value_lookup_string(args, "textAlign");

  if (al && fl_value_get_type(al) == FL_VALUE_TYPE_STRING) {
    const char* s = fl_value_get_string(al);
  
    if (strcmp(s, "left") == 0) {
      pip_instance->text_align = ALIGN_LEFT;
    } else if (strcmp(s, "right") == 0) {
      pip_instance->text_align = ALIGN_RIGHT;
    } else {
      pip_instance->text_align = ALIGN_CENTER;
    }
  }

  FlValue* ratio_val = fl_value_lookup_string(args, "ratio");
  if (ratio_val && fl_value_get_type(ratio_val) == FL_VALUE_TYPE_LIST
      && fl_value_get_length(ratio_val) >= 2) {
        int r1 = fl_value_get_int(fl_value_get_list_value(ratio_val, 0));
        int r2 = fl_value_get_int(fl_value_get_list_value(ratio_val, 1));
        if (r1 > 0 && r2 > 0) {
          int height = 180;
          int width = height * r1 / r2;          
          gtk_window_resize(GTK_WINDOW(pip_instance->window), width, height);
        }
  }

  gtk_widget_queue_draw(pip_instance->drawing_area);

  auto result = fl_value_new_bool(TRUE);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}


FlMethodResponse* start_pip() {
  if (pip_instance) {
    gtk_widget_show_all(pip_instance->window);
    // Position in center
    gtk_window_set_position(GTK_WINDOW(pip_instance->window), GTK_WIN_POS_CENTER);
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* stop_pip() {
  if (pip_instance) {
    gtk_widget_hide(pip_instance->window);
    
    // Notify Flutter that PiP was stopped
    if (pip_instance->method_channel != nullptr) {
      g_autoptr(FlValue) notify_result = fl_value_new_bool(TRUE);
      fl_method_channel_invoke_method(pip_instance->method_channel, "pipStopped", notify_result, nullptr, nullptr, nullptr);
    }
    
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* is_pip_supported() {
  // PiP is supported on Linux
  g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* update_text(FlValue* args) {
  if (pip_instance && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue* text_value = fl_value_lookup_string(args, "text");
    if (text_value != nullptr && fl_value_get_type(text_value) == FL_VALUE_TYPE_STRING) {
      pip_instance->current_text = fl_value_get_string(text_value);
      gtk_widget_queue_draw(pip_instance->drawing_area);
      g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
      return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    }
  }
  g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Called when a method call is received from Flutter.
static void pip_plugin_handle_method_call(
    PipPlugin* self,
    FlMethodCall* method_call,
    FlMethodChannel* channel) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "setupPip") == 0) {
    response = setup_pip(args, channel);
  } else if (strcmp(method, "startPip") == 0) {
    response = start_pip();
  } else if (strcmp(method, "stopPip") == 0) {
    response = stop_pip();
  } else if (strcmp(method, "isPipSupported") == 0) {
    response = is_pip_supported();
  } else if (strcmp(method, "updateText") == 0) {
    response = update_text(args);
  } else if (strcmp(method, "updatePip") == 0) {
    response = update_pip(args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void pip_plugin_dispose(GObject* object) {
  // Clean up PiP window if it exists
  if (pip_instance) {
    gtk_widget_destroy(pip_instance->window);
    delete pip_instance;
    pip_instance = nullptr;
  }
  
  G_OBJECT_CLASS(pip_plugin_parent_class)->dispose(object);
}

static void pip_plugin_class_init(PipPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = pip_plugin_dispose;
}

static void pip_plugin_init(PipPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  PipPlugin* plugin = PIP_PLUGIN(user_data);
  pip_plugin_handle_method_call(plugin, method_call, channel);
}

void pip_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  PipPlugin* plugin = PIP_PLUGIN(
      g_object_new(pip_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "pip_plugin",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}