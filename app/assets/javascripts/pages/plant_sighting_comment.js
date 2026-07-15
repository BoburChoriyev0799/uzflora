$(function() {
    $("#add-plant-sighting-comment").on("click", function(event) {
        event.preventDefault();
        var $this = $(this);

        var form = $(this).closest('#form-add-plant-sighting-comment');
        var tag_input = $(this).parent().find('.comment-text');
        var comment_text = tag_input.val();

        if (!comment_text || comment_text.trim().length === 0) {
            return;
        }

        $.post(
            form.attr('action'),
            { comment: comment_text, plant_sighting_id: form.data('plant-sighting-id') },
            function(response) {
                if (response.success) {
                    tag_input.val('');
                    var comment_html =
                        "<div class='row comment-row mbtm15'>" +
                            "<div class='col-md-1 image-holder'>" +
                                "<img src='" + form.data('user-avatar') + "' class='img-circle' />" +
                            "</div>" +
                            "<div class='col-md-10 comment-holder'>" +
                                "<p class='row-link'>" +
                                    "<div class='row'>" +
                                        "<div class='col-md-9'><a href='" + form.data('user-profile') + "'>" + form.data('user-name') + "</a></div>" +
                                    "</div>" +
                                "</p>" +
                                "<p class='row-comment'>" + response.text + "</p>" +
                            "</div>" +
                            "<div class='col-md-1 delete-comment-container'>" +
                                "<a href='#' class='delete-plant-sighting-comment-lnk' data-id='" + response.id + "'></a>" +
                            "</div>" +
                        "</div>";
                    $this.closest('.bird-photo-comments').find('.comments-container').append($(comment_html));
                }
            }
        );
    });

    $('.comments-container').on('click', '.delete-plant-sighting-comment-lnk', function(event) {
        event.preventDefault();
        var $this = $(event.target);
        var comment_id = $this.data('id');

        $.ajax({
            url: '/plant_sighting_comments/' + comment_id,
            type: 'DELETE',
            success: function() {
                $this.closest('.row.comment-row').remove();
            }
        });
    });
});
