var REGEX_EMAIL = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$/;
var REGEX_URL = /^[fh]t{1,2}ps?:\/\/[a-zA-Z0-9\-_\.]+(:[0-9]+)?(\/[a-zA-Z0-9\/`~!@#\$%\^&\*\(\)\-_=\+{}\[\]\|\\;:'",<\.>\?])?/;

/* ------------------------------------------------------------------------------------------------------------------------
 * Generic form input field validation
 *     This method expects that the flds passed in are arrays and that they contain the id/name of form inputs
 *     The method also expects that the inputs have a label attached to them. 
 *     The must_match_flds param should contain an array of arrays (e.g. [ ["password", "confirmation"], ["field1", "field2"] ])
 *
 *     The method returns a list of errors or an empty string if all fields are valid
 *
 *     TODO - move hard-coded messages to the html.yml file!
 * ------------------------------------------------------------------------------------------------------------------------ */
function validate(required_flds, email_flds, url_flds, must_match_flds){
  var ret = '';

  try {
    // Process the REQUIRED fields
    $.each(required_flds, function(idx, val) {
      if($("#" + val).val().trim() == '')
      ret += $("label[for='" + val + "']").html().replace(':', '') + " cannot be blank!<br />";
    });

    // Process the EMAIL fields
    $.each(email_flds, function(idx, val) {
      if( $("#" + val).val().trim() != '' ){
        if( !REGEX_EMAIL.test( $("#" + val).val().trim() ) ) {
          ret += $("label[for='" + val + "']").html().replace(':', '') + " is not a valid email address!<br />";
        }
      }
    });

    // Process the URL fields
    $.each(url_flds, function(idx, val) {
      if( $("#" + val).val().trim() != '' ){
        if( !REGEX_URL.test( $("#" + val).val().trim() ) ) {
          ret += $("label[for='" + val + "']").html().replace(':', '') + " is not valid (make sure you include the http:// or https://)!<br />";
        }
      }
    });

    // Process the MUST MATCH fields
    $.each(must_match_flds, function(idx, matchers) {
      var prev = '', labels = '', failed = false;

      $.each(matchers, function(idx, val){
        if(labels != ''){
          labels += " and "
        }
        // Record the labels of each input for the failure message
        labels += $("label[for='" + val + "']").html().replace(':', '')

        // If the input's value doesn't match it's predecessor, its a failure
        if(prev != '' && prev != $("#" + val).val().trim()){
          failed = true;
        }
        prev = $("#" + val).val()
      });

      if(failed){
        ret += labels + " MUST match!";
      }
    });

  }catch(e){
    ret = "An unexpected error occurred: " + e.message;
  }

  return ret;
}

function reset_form_criteria(err_msg){
  // Do an ajax call to the report controller to grab the defaults
  $.ajax({
    url: '/report/defaults',
    type: 'get',
    success: function(data) { 
      var defaults = $.parseJSON(data);
      
      $("#url").val('');
      $("#userid").val('');

      $("#pid_low").val(defaults.pid_min);
      $("#pid_high").val(defaults.pid_max);

      $("#created_low").val(defaults.created_low);
      $("#created_high").val(defaults.created_high);
      $("#modified_low").val(defaults.modified_low);
      $("#modified_high").val(defaults.modified_high);
      $("#accessed_low").val(defaults.accessed_low);
      $("#accessed_high").val(defaults.accessed_high);

      $("#active").val('');
    },
    error: function(data) {
      $(".errors").html(err_msg);
    }
  });
}