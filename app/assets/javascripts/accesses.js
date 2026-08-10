$(function() {
    $('table.table').sortable({
        items: 'tr',
        axis: 'y',
        dropOnEmpty: false,
        handle: '.handle',
        cursor: 'move',
        update: function(event, ui) {
            var dragged = ui.item.attr("id").split('_')[1]
            $.ajax({
                url: '/accesses/move/'+dragged,
                type: 'post',
                data: $('table.table').sortable('serialize'),
                dataType: 'script',
                complete: function (request) {
                    location.reload();
                }
            });
        }
    });
});
