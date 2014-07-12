var EveSRP;

if (!EveSRP) {
  EveSRP = {}
}

if (! ('ui' in EveSRP)) {
  EveSRP.ui = {}
}

EveSRP.ui.renderFlashes = function renderFlashes(data) {
  var $content = $('#content'),
      flashes = data.flashed_messages;
  for (index in flashes) {
    var flashID = _.random(10000),
        flashInfo = flashes[index],
        flash;
    flashInfo.id = flashID;
    flash = Handlebars.templates.flash(flashes[index])
    $content.prepend(flash);
    window.setTimeout(function() {
      $('#flash-' + flashID).alert('close');
    }, 5000);
  }
};

EveSRP.ui.setupEvents = function setupUIEvents() {
  $(document).ajaxComplete(function(ev, jqxhr) {
    var data = jqxhr.responseJSON;
    if (data && 'flashed_messages' in data) {
      EveSRP.ui.renderFlashes(jqxhr.responseJSON);
    }
  });
};
EveSRP.ui.setupEvents();
