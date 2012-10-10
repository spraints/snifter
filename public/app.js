$(function() {
  $('body').delegate('.revealer', 'click', function() {
    $(this).slideUp();
    $($(this).data('target')).slideDown();
  });

  $('body').delegate('#view-res-body', 'click', function(e) {
    $('#res-body').toggle();
    e.preventDefault();
  });

  $('body').delegate('#view-req-body', 'click', function(e) {
    $('#req-body').toggle();
    e.preventDefault();
  });

  $('body').delegate('.session', 'click', function(e) {
    e.preventDefault();
    $('#results').load($(this).attr('href'));
    $('.current_session').removeClass('current_session');
    $(this).closest('td').addClass('current_session');
  });

  $('body').delegate('a[href][data-method]', 'click', function(e) {
    var method = $(this).data('method');
    if(method && method.toLowerCase() != 'get') {
      e.preventDefault();
      $('<form action="'+$(this).attr('href')+'" method="'+method+'">'+
        '<input type="hidden" name="return_to" value="'+location.href+'"/>'+
        '</form>').appendTo($('body')).submit();
    }
  });

  var loading_html = '<div class="loading"></div>';

  $('body').delegate('a.tweaker', 'click', function(e) {
    e.preventDefault();
    var overlay = $('<div class="tweaker-overlay"></div>');
    var container = $('<div class="tweaker-container"><h1>Tweak a request</h1></div>');
    var body = $('<div class="tweaker-body"></div>');
    var response = $('<div class="tweaker-response"></div>');
    var close = $('<button class="tweaker-close">close</button>');
    overlay.appendTo($('body')).append(container);
    container.append(close).append(body).append(response);
    body.html(loading_html).load($(this).attr('href'));
    close.on('click', function() { overlay.remove(); } );
  });

  $('body').delegate('form.tweaker', 'submit', function(e) {
    e.preventDefault();
    var loading = $(loading_html);
    function complete(responseText, textStatus, xhr) {
      if(textStatus == "error") {
        loading.removeClass('loading').text("Oops!! I couldn't run that request!");
        console.log(["tweaked request result", textStatus, responseText]);
      }
    };
    $('.tweaker-response').append(loading).load($(this).attr('action'), $(this).serializeArray(), complete);
  });

  var steps = "\\|/-";
  var step = 0;
  setInterval(function() {
    step = (step + 1) % steps.length;
    $('.loading').html(steps[step]);
  }, 250);
});
