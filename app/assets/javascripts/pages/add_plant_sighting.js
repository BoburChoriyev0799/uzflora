$(function() {
    //*** Plant sighting photo preview ***
    $('.add-photo-container #plant_sighting_photo').on('change', function(event) {
        var reader = new FileReader();
        reader.onload = function(file) {
            $('#set-plant-photo-preview').attr('src', file.target.result);
        }
        var photo = event.target.files[0];
        reader.readAsDataURL(photo);
        $('#set-plant-photo-path').val(photo.name);
    });

    //*** Photo's date ***
    // Kalendar 2020-yildan bugungi kungacha ochiq; kelajak sanalar bloklangan.
    // Sarlavhani bosish (masalan "Iyul 2026") oy/yil ro'yxatiga tez o'tkazadi —
    // bu bootstrap-datetimepicker'ning standart xatti-harakati.
    $('#plant-sighting-datetime-group').datetimepicker({
        locale: 'ru',
        format: 'DD/MM/YYYY',
        minDate: moment('2020-01-01', 'YYYY-MM-DD'),
        maxDate: moment(),
        useCurrent: false
    });
});
