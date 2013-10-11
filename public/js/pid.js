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
      if($.trim($("#" + val).val()) == '')
      ret += $("label[for='" + val + "']").html().replace(':', '') + " cannot be blank!<br />";
    });

    // Process the EMAIL fields
    $.each(email_flds, function(idx, val) {
      if($.trim($("#" + val).val()) != '' ){
        if( !REGEX_EMAIL.test( $("#" + val).val().trim() ) ) {
          ret += $("label[for='" + val + "']").html().replace(':', '') + " is not a valid email address!<br />";
        }
      }
    });

    // Process the URL fields
    $.each(url_flds, function(idx, val) {
      if($.trim($("#" + val).val()) != '' ){
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
        if(prev != '' && prev != $.trim($("#" + val).val())){
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
      $("#groupid").val('');

      $("#pid_low").val(defaults.pid_low);
      $("#pid_high").val(defaults.pid_high);
      $("#pid_set").val('');

      $("#created_low").val(defaults.created_low);
      $("#created_high").val(defaults.created_high);
      $("#modified_low").val(defaults.modified_low);
      $("#modified_high").val(defaults.modified_high);
      $("#accessed_low").val(defaults.accessed_low);
      $("#accessed_high").val(defaults.accessed_high);

      $("#interesteds").val('');

      $("#active").val('');
    },
    error: function(data) {
      $(".errors").html(err_msg);
    }
  });
}


/*
 * ---------------------------------------------------------------------------------------------------
 * Sorts the specified json data and updates the specified table with the sorted values
 * ---------------------------------------------------------------------------------------------------
 */
var sort_col = 'id';
var sort_dir = 'asc';

function sort_json_data(json, column){  
  // Set the sort column and the direction
  if(sort_col != column){
    sort_col = column;
    sort_dir = 'asc';
  }else{
    sort_dir = (sort_dir == 'asc') ? 'desc' : 'asc';
  }

  // Resort the JSON data according to the selected column
  json.sort( function(x,y) {
    // Sort the data either ASC or DESC depending on the current direction, only do a String comparison if its not the PID id
    if(sort_dir == 'asc'){
      return (x[sort_col] > y[sort_col]) ? 1 : (x[sort_col] < y[sort_col]) ? -1 : 0;
    }else{
      return (y[sort_col] > x[sort_col]) ? 1 : (y[sort_col] < x[sort_col]) ? -1 : 0;
    }
  });
  
  return json;
}

/*
 * ---------------------------------------------------------------------------------------------------
 * Table Pagination Functions
 * ---------------------------------------------------------------------------------------------------
 */
var pagination_page_size = 100;
var pagination_total_lines = 0;
var pagination_last_page = 1;
 
// Initialize the pagination parameters for the page
function paginate_init(page_size, line_count){
  // Make sure that a positive value was passed into the function
  pagination_page_size = (page_size > 1) ? page_size : 100;
  pagination_total_lines = (line_count > 0) ? line_count : 0;
  
  // Determine the total number of pages
  if((pagination_total_lines % pagination_page_size) == 0){
    pagination_last_page = pagination_total_lines / pagination_page_size;
  }else{
    pagination_last_page = Math.floor(pagination_total_lines / pagination_page_size) + 1;
  }
}

// Adds the pagination navigation to the specified table
function pagination_build_nav(table, current_page){
  // Remove the old pagination row
  var rows = table.find('tr.page_nav');
  
  if(rows.length > 0){
    rows.remove();
  }
  
  // If the total page size is less than the total number of records then build out the table pagination
  if(pagination_page_size < pagination_total_lines){
    // Make sure the current page is valid
    var page = (current_page > 0) ? ((current_page <= pagination_last_page) ? current_page : pagination_last_page) : 1;
  
    // Figure out how many column headings there are for the colspan value
    var col_count = table.find('th').size();
    
    var nav = '<tr class="page_nav">' +
                '<th colspan="' + col_count + '" class="pagination">Go to page:&nbsp;&nbsp;';
    
    // If there are more than 15 pages, show: 1 ... [5 less than the current page] - [5 more than the current page] ... [last page] 
    if(pagination_last_page > 15){
      nav += (page == 1) ? '<span>1</span>' : '<a href="#" onclick="$(\'#current_page\').val(1); changePage(); return false;">1</a>';
      
      // Determine the start are end pages
      var start = ((page < 15) ? 2 : (page > (pagination_last_page - 15)) ? (pagination_last_page - 15) : (page - 5));
      var end = ((page < 15) ? 15 : (page > (pagination_last_page - 15)) ? (pagination_last_page - 1) : (page + 5));
      
      if(page >= 15){
        nav += '<span>...</span>';
      }
      
      for(var i = start; i <= end; i++){
        nav += (page == i) ? '<span>' + i + '</span>' : '<a href="#" onclick="$(\'#current_page\').val(' + i + '); changePage(); return false;">' + i + '</a>';
      }
      
      if(page <= (pagination_last_page - 15)){
        nav += '<span>...</span>';
      }
      
      nav += (page == pagination_last_page) ? '<span>' + pagination_last_page + '</span>' : '<a href="#" onclick="$(\'#current_page\').val(' + pagination_last_page + '); changePage(); return false;">' + pagination_last_page + '</a>';

    }else{
      for(var i = 1; i <= pagination_last_page; i++){
        nav += (page == i) ? '<span>' + i + '</span>' : '<a href="#" onclick="$(\'#current_page\').val(' + i + '); changePage(); return false;">' + i + '</a>';
      }
    }
    nav += '<input type="hidden" id="current_page" value="' + page + '" /></th></tr>';
    
    table.find('tr').first().before(nav);
    table.find('tr').last().after(nav);
  }
}

// Returns a subset of the specified json that matches the current page
function paginate_json(json, current_page){
  var ret_json = [];
  
  // If the total page size is less than the total number of records then build out the table pagination
  if(pagination_page_size < pagination_total_lines){
    
    // Make sure the current page is valid
    var page = (current_page > 0) ? ((current_page <= pagination_last_page) ? current_page : pagination_last_page) : 1;
    
    // Determine what record we should start and end with
    var start = pagination_page_size * (page - 1);
    var end = (start + (pagination_page_size - 1) > pagination_total_lines) ? pagination_total_lines : (start + pagination_page_size);
  
    for(var i = start; i < end; i++){
      ret_json.push(json[i]);
    }
    
  }else{
    ret_json = json;
  }
  
  return ret_json;
}
