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
});
