# Which application opens which document type.
#
# Without this the association comes from mimeinfo.cache in whichever directory
# of XDG_DATA_DIRS wins, which happens to be the Nix profile today and therefore
# happens to be right. That is luck, not configuration: Ubuntu ships GNOME's
# document viewer and a desktop update can re-register these types at any time.
#
# Taking over ~/.config/mimeapps.list means Home Manager owns the whole file, so
# the Thunderbird scheme handler that was already in it is carried over below --
# dropping it would silently break mailto-style links from Thunderbird itself.
{ ... }:

{
  xdg.mimeApps.enable = true;

  xdg.mimeApps.defaultApplications =
    let
      writer = [ "writer.desktop" ];
      calc = [ "calc.desktop" ];
      impress = [ "impress.desktop" ];
      draw = [ "draw.desktop" ];
    in
    {
      # --- Microsoft formats, the reason this file exists -----------------
      # Every type below is one the corresponding .desktop actually declares in
      # its MimeType= line; checked rather than assumed, so none of these is a
      # default for an application that does not claim to handle it.
      "application/msword" = writer; # .doc
      "application/vnd.ms-word" = writer;
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = writer; # .docx
      "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = writer; # .dotx
      "application/vnd.ms-word.document.macroEnabled.12" = writer; # .docm

      "application/vnd.ms-excel" = calc; # .xls
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = calc; # .xlsx
      "application/vnd.openxmlformats-officedocument.spreadsheetml.template" = calc; # .xltx
      "application/vnd.ms-excel.sheet.macroEnabled.12" = calc; # .xlsm
      "application/vnd.ms-excel.sheet.binary.macroEnabled.12" = calc; # .xlsb

      "application/vnd.ms-powerpoint" = impress; # .ppt
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = impress; # .pptx
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow" = impress; # .ppsx
      "application/vnd.openxmlformats-officedocument.presentationml.template" = impress; # .potx
      "application/vnd.ms-powerpoint.presentation.macroEnabled.12" = impress; # .pptm

      # --- OpenDocument, same suite ---------------------------------------
      "application/vnd.oasis.opendocument.text" = writer; # .odt
      "application/vnd.oasis.opendocument.text-template" = writer; # .ott
      "application/vnd.oasis.opendocument.spreadsheet" = calc; # .ods
      "application/vnd.oasis.opendocument.spreadsheet-template" = calc; # .ots
      "application/vnd.oasis.opendocument.presentation" = impress; # .odp
      "application/vnd.oasis.opendocument.presentation-template" = impress; # .otp
      "application/vnd.oasis.opendocument.graphics" = draw; # .odg

      "application/rtf" = writer;

      # Deliberately NOT text/csv. Calc declares it, but a .csv is as often
      # something to read or diff as a spreadsheet to open, and silently routing
      # it through a spreadsheet is the kind of default that surprises people.

      # --- Carried over from the pre-existing mimeapps.list ----------------
      "x-scheme-handler/net.thunderbird" = [ "thunderbird_thunderbird.desktop" ];
    };

  # The file already existed as a plain file, so activation refuses with
  # "Existing file ... would be clobbered". Forcing it hands ownership over, and
  # nothing is lost because its only entry is reproduced above.
  #
  # Note the form: `xdg.configFile."mimeapps.list"`, which is what the mimeApps
  # module itself uses. Writing the same thing as
  # `home.file."${config.xdg.configHome}/mimeapps.list".force` addresses the very
  # same attribute and fails with "has conflicting definition values" -- the
  # mirror image of the trap in home/vscodium.nix, where the relative form was
  # the wrong one.
  xdg.configFile."mimeapps.list".force = true;
}
