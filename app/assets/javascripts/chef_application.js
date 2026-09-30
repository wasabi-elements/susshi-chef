// Application wide code loaded on all pages with layout

jQuery.fn.submitOnChange = function() {
    this.find('*').change(function() {
        $(this).parent('form').submit();
    });
    return this;
};

jQuery.fn.submitOnChangeWithLI = function() {
    this.find('*').change(function() {
        $(this).parent('form').submit();
        $(this).parent('form').find('#load_indicator').show();
    });
    return this;
};

registerAutoSubmitSearchForm = function() {
    $("form.auto_submit_on_change").submitOnChangeWithLI();
};

registerAutoSubmitOnAutocomplete = function() {
    $("[data-autocomplete]").change(function() {
        $(this).parent('form').submit();
        $(this).parent('form').find('#load_indicator').show();
    });
};

registerClearSearchForm = function() {
    $("input.button_clear_search_form").on('click', function() {
        $(this).closest("form").find('input, select').not(':button, :submit, :reset, :hidden, :checkbox, .no_clear').val('').removeAttr('checked').removeAttr('selected').css("color: red");
        $(this).closest("form").find('input:checkbox').not('.no_clear').removeAttr('checked');
        $(this).closest("form").submit();
    });
};

registerDynamicFields = function() {
    /* rebinding via namespace avoids stacked handlers when called again for modal dialogs */
    $("form").off('click.dynamicFields').on('click.dynamicFields', '.add-fields', function(event) {
        event.preventDefault();
        var all_inputs = $(this).parent().parent().find('input, textarea');
        var last_input = all_inputs.last();
        var max = last_input.data('max');

        /* clone the single last field only, never the surrounding input-group */
        if (all_inputs.length < max) {
            var last_row = last_input.closest('div.array-row');
            if (last_row.length > 0) {
                /* input_with_icon: clone the row holding one field, its icon and remove button */
                var new_row = last_row.clone();
                new_row.find('input').val('').removeAttr('id');
                last_row.after(new_row);
            } else {
                last_input.after(last_input.clone().val('').removeAttr('id'));
            }
        }
        if (all_inputs.length + 1 >= max) {
            $(this).remove();
        }
    }).on('click.dynamicFields', '.remove-field', function(event) {
        event.preventDefault();
        var row = $(this).closest('div.array-row');

        /* keep the last row, so there is still a field to enter values */
        if (row.siblings('div.array-row').length > 0) {
            row.remove();
        } else {
            row.find('input').val('');
        }
    }).on('click.dynamicFields', '.clear-field', function(event) {
        event.preventDefault();
        $(this).closest('div.input-group').find('input').val('');
    });
};

jQuery.fn.Chosen = function(params) {
    var defaults = {
        /* width: '90%', */
        allow_single_deselect: true,
        search_contains: true,
        single_backstroke_delete: false,
        no_results_text: 'No results matched',
        placeholder_text_single: 'Please select',
        placeholder_text_multiple: 'Please select some options'
    };

    var chosen = $.extend(defaults, params);

    this.chosen(chosen);
    return this;
};

registerChosen = function() {
    // Chosen - Activate by class
    $('select.chosen').Chosen();

    // Chosen - Activate by number of options
    $('select').not('select.chosen,select.no-chosen,select.dual_select,.bootstrap-duallistbox-container select').each(function() {
        if ($(this).children('option').length <= 15) {
            $(this).Chosen({disable_search: true});
        } else {
            $(this).Chosen();
        }
    });
};

markTabsWithErrors = function() {
    $('div.has-error').each(function (index, value) {
        var tab_id = $(this).first().parents('div.tab-pane').attr('id');

        if (tab_id) {
            var link = $(this).first().parents('div.tabs-container').find('div.tabs-top a[href$="'+tab_id+'"]');
            var text = link.text();
            link.html('<i class="fa fa-exclamation-triangle text-danger"></i><span class="text-danger">'+text+'</span>')
        }
    });
};

registerUpdateSshKeyInput = function() {
    $('form').on('change keyup paste', 'textarea.sshkey-input-with-title', function() {
        var terms = $(this).val().split(/\s+/);
        if (terms[0].charAt(0) != '-' ) {
            if (terms.length > 2) {
                var title = terms;
                title.shift();
                title.shift();
                $(this).parents('div.key-group').first().find('input').val(title.join(' '));
            }
        }
    });
};

showModalDialog = function() {
    if ($("#modal-dialog").children().length > 0) {
        $("#modal-dialog").modal('show');
    };
};

registerDynamics = function() {
    registerDynamicFields();
    registerChosen();
    $('.dual_select').bootstrapDualListbox({
        selectorMinimalHeight: 160,
        moveOnSelect: true,
        helperSelectNamePostfix: false
    });
    registerUpdateSshKeyInput();
    showModalDialog();
};

registerAll = function() {
    /* Display Flash message */
    $("div.flash").show().delay(5000).fadeOut(2000).fadeIn(0);

    registerAutoSubmitSearchForm();
    registerAutoSubmitOnAutocomplete();
    registerClearSearchForm();
    markTabsWithErrors();

    registerDynamics();

    $('.datepicker').datepicker();
};



// Register functions after page load
$(function() {
    registerAll();
});

$(document).on('page:load', registerAll);
