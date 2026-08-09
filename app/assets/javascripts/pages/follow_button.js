// "Kuzatish"/"Kuzatilmoqda" tugmasi (profil sahifasi). Boshqa profil
// sahifasiga o'tilganda konteyner butunlay yangi DOM tugun bo'lgani
// uchun (masalan moderate_plant_sightings.js'dagi kabi) konteynerga
// bog'langan handler emas, balki plant_autocomplete.js'dagi kabi
// document'ga bog'langan (delegated) va nomlangan handler ishlatiladi —
// Turbolinks har qanday holatda ham (skript qayta ishga tushsa ham,
// tushmasa ham) ishlayveradi.
(function () {
  $(document)
    .off('click.followBtn')
    .on('click.followBtn', '.follow-btn', function (event) {
      event.preventDefault();
      var $btn = $(this);
      if ($btn.prop('disabled')) {
        return;
      }

      var userId = $btn.data('userId');
      var isFollowing = $btn.data('following') === true || $btn.data('following') === 'true';
      var url = '/users/' + userId + (isFollowing ? '/unfollow' : '/follow');

      $btn.prop('disabled', true);

      $.ajax({
        url: url,
        type: isFollowing ? 'DELETE' : 'POST',
        dataType: 'json'
      }).done(function (response) {
        if (!response.success) {
          alert(response.error || 'Xatolik yuz berdi.');
          return;
        }

        var nowFollowing = !!response.following;
        $btn.data('following', nowFollowing);
        $btn.toggleClass('following', nowFollowing);
        $btn.text(nowFollowing ? $btn.data('followingLabel') : $btn.data('followLabel'));

        if (typeof response.followers_count !== 'undefined') {
          $('.followers-count').text(response.followers_count);
        }
      }).fail(function () {
        alert('Xatolik yuz berdi, birozdan so\'ng qayta urinib ko\'ring.');
      }).always(function () {
        $btn.prop('disabled', false);
      });
    });
})();
