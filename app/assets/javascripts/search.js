// BigBlueButton open source conferencing system - http://www.bigbluebutton.org/.
//
// Copyright (c) 2018 BigBlueButton Inc. and by respective authors (see below).
//
// This program is free software; you can redistribute it and/or modify it under the
// terms of the GNU Lesser General Public License as published by the Free Software
// Foundation; either version 3.0 of the License, or (at your option) any later
// version.
//
// BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
// PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License along
// with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

$(document).on('turbolinks:load', function(){
    var controller = $("body").data('controller');
    var action = $("body").data('action');

    if(controller == "rooms" && action == "show"){
        search_input = $('#search_bar');
        
        search_input.bind("keydown", function(event){
            alert("Search input clicked");

            search_query = search_input.find(".form-control").val();
            if(event.key == "Backspace"){
                alert(search_query.substring(0, search_query.length - 1));
            }
            else{
                alert(search_query + String.fromCharCode(event.keyCode));
            }

            //Search for recordings and display them based on name match
            recordings_table = $(".table-responsive");
            //recordings_table.click(function(){
            //    alert("Recordings table clicked");
            //});

            recordings = recordings_table.find('tbody:tr');
            recordings.each(function(){
                alert($(this).find('div')[0]);
            });

        });
    }
});