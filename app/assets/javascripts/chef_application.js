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
    $("form").on('click', '.add-fields', function(event) {

        var length;
        var max;
        var all_input_groups;
        var group = $(this).data('group');

        if (group) {
            var all_input_groups = $('div.add-group.'+group);
            length = all_input_groups.length;
            max = $(this).data('max');
            if (max == null) {
                max = 100;
            }
        } else {
            var all_inputs = $(this).parent().parent().find('input, textarea');
            var last_input = all_inputs.last();
            all_input_groups = last_input.parent('div.input-group');
            length = all_inputs.length;
            max = all_inputs.last().data('max');
        }
        if (length < max) {
            if (all_input_groups.length > 0) {
                /* clone group and remove index if any */
                var new_objects = all_input_groups.last().clone();
                var time = new Date().getTime();
                new_objects.find('input, textarea').each(function (index, value) {
                    var name = $(this).attr('name').replace(/\[[0-9]+\]/g, '['+time+']');
                    $(this).attr('name', name).val('');
                });
                all_input_groups.last().after(new_objects);
                all_input_groups.last().addClass('margin-bottom-sm');
            } else {
                last_input.after(last_input.clone().val(null));
            }
            event.preventDefault();
        }
        if (length + 1 == max) {
            $(this).remove();
        }
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
