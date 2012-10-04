$(function() {
  $('body').delegate('.revealer', 'click', function() {
    $(this).slideUp();
    $($(this).data('target')).slideDown();
  });
});
