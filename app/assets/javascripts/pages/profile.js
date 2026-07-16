$(function() {
    $('.profile-menu, .profile-container .mobile-blocks-nav a').on('click', function(event) {
        event.preventDefault();

        var is_active_block = $(this).hasClass('active');
        var is_mobile_block = $(this).parent().hasClass('mobile-blocks-nav');

        if (is_active_block && !is_mobile_block) {
            return;
        }

        $(".mobile-blocks-nav a").removeClass("active");
        $(".sub-nav-pils a").removeClass("active");
        $(".blocks-content .profile-block-container").removeClass("active-block");

        if (!is_active_block) {
            show_block = $(this).data('view');
            $("a[data-view='" + show_block + "']").addClass("active");
            $(".blocks-content div#" + show_block + "").addClass("active-block");
        }
    });

    $('.input-group .g-pencil').on('click', function(e) {
        e.preventDefault();
        $(e.target).prev().trigger('click');
    });

    $('#change-avatar').on('click', function() {
        $('#avatar-file-field').trigger('click');
    });

    $('#avatar-file-field').on('change', function(event) {
        $(this).closest('form').submit();
    });

    $('.profile-birds-container, .map-img-container').on('click', '.delete_user_bird', function(event) {
        event.preventDefault();
        var $this = $(event.target);

        var result = confirm("Rostdan ham suratni o'chirmoqchimisiz?");
        if (result) {
            var bird_id = $this.data('id');
            $.ajax({
                url: '/birds/' + bird_id,
                type: 'DELETE',
                success: function(result) {
                    $this.closest('.profile-bird-container').remove();
                    if (result['published']) {
                        $('.profile-birds-count').html('[' + result['count'] + ']');
                    }
                    else {
                        $('.profile-drafts-count').html('[' + result['count'] + ']');
                    }
                }
            });
        }
    });

    $('.profile-birds-container').on('click', '.delete_user_plant_sighting', function(event) {
        event.preventDefault();
        var $this = $(event.target);

        var result = confirm("Rostdan ham suratni o'chirmoqchimisiz?");
        if (result) {
            var sighting_id = $this.data('id');
            $.ajax({
                url: '/plant_sightings/' + sighting_id,
                type: 'DELETE',
                success: function(result) {
                    $this.closest('.profile-bird-container').remove();
                    if (result['published']) {
                        $('.profile-birds-count').html('[' + result['count'] + ']');
                    }
                    else {
                        $('.profile-drafts-count').html('[' + result['count'] + ']');
                    }
                }
            });
        }
    });

    $('.comments-container').on('click', '.delete-profile-plant-sighting-comment-lnk', function(event) {
        event.preventDefault();
        var $this = $(event.target);
        var comment_id = $this.data('id');

        $.ajax({
            url: '/plant_sighting_comments/' + comment_id,
            type: 'DELETE',
            success: function(result) {
                $this.closest('.row.comment-row').remove();
                $('.profile-comments-count').html('[' + result['count'] + ']');
            }
        });
    });

    $('#subscribe_data').on('ajax:success', function(event, data) {
        var $feedback = $('#subscribe-feedback');
        $feedback.removeClass('error').text(data['subscribed'] ? $feedback.data('subscribed') : $feedback.data('unsubscribed'));
    }).on('ajax:error', function(event, data, status, xhr) {
        var $feedback = $('#subscribe-feedback');
        $feedback.addClass('error').text($feedback.data('error'));
    });

});
