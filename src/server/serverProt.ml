(**
 * Copyright (c) 2013-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "flow" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

type file_input =
| FileName of string
| FileContent of string option * string (* filename, content *)

let path_of_input = function
| FileName f -> Some f
| FileContent (Some f, _) -> Some f
| _ -> None

let file_input_get_filename = function
  | FileName fn -> fn
  | FileContent (Some fn, _) -> fn
  | FileContent (None, _) -> "-"

let file_input_get_content = function
  | FileName fn -> Sys_utils.cat fn
  | FileContent (_, content) -> content

let build_revision = match Build_id.build_revision with
  | "" -> FlowConfig.version
  | x -> x

type command =
| AUTOCOMPLETE of file_input
| CHECK_FILE of
    file_input *
    Verbose.t option *
    bool * (* graphml *)
    bool (* force *)
| COVERAGE of file_input * bool (* force *)
| DUMP_TYPES of file_input * bool (* filename, include raw *) * (Path.t option) (* strip_root *)
| ERROR_OUT_OF_DATE
| FIND_MODULE of string * string
| FIND_REFS of file_input * int * int (* filename, line, char *)
| GEN_FLOW_FILES of file_input list
| GET_DEF of file_input * int * int (* filename, line, char *)
| GET_IMPORTS of string list
| INFER_TYPE of
    file_input * (* filename|content *)
    int * (* line *)
    int * (* char *)
    Verbose.t option *
    bool (* include raw *)
| KILL
| PORT of string list
| STATUS of Path.t
| FORCE_RECHECK of string list
| SUGGEST of (string * string list) list
| CONNECT

type command_with_context = {
  client_logging_context: FlowEventLogger.logging_context;
  command: command;
}

type autocomplete_response = (
  AutocompleteService_js.complete_autocomplete_result list,
  string
) result
type coverage_response = (
  (Loc.t * bool) list,
  string
) result
type dump_types_response = (
  (Loc.t * string * string * string option * Reason.t list) list,
  string
) result
type find_refs_response = (Loc.t list, string) result
type get_def_response = (Loc.t, string) result
type infer_type_response = (
  Loc.t * string option * string option * Reason.t list,
  string
) result
(* map of files to `Ok (line, col, annotation)` or `Error msg` *)
type suggest_response = ((int * int * string) list, string) result SMap.t

type gen_flow_file_error =
  | GenFlowFile_TypecheckError of Errors.ErrorSet.t
  | GenFlowFile_UnexpectedError of string
type gen_flow_file_result =
  | GenFlowFile_FlowFile of string
  | GenFlowFile_NonFlowFile
type gen_flow_file_response =
  ((string * gen_flow_file_result) list, gen_flow_file_error) result
type port_response = (string, exn) result SMap.t

type directory_mismatch = {
  server: Path.t;
  client: Path.t;
}

type response =
| DIRECTORY_MISMATCH of directory_mismatch
| ERRORS of Errors.ErrorSet.t
| NO_ERRORS
| SERVER_DYING
| SERVER_OUT_OF_DATE
| NOT_COVERED

let response_to_string = function
  | DIRECTORY_MISMATCH _ -> "Directory Mismatch"
  | ERRORS _ -> "Some Errors"
  | NO_ERRORS -> "No Errors"
  | NOT_COVERED -> "No Errors (Not @flow)"
  | SERVER_DYING -> "Server Dying"
  | SERVER_OUT_OF_DATE -> "Server Out of Date"

module Persistent_connection_prot = struct
  type request =
    | Subscribe
    | Autocomplete of (file_input * (* request id *) int)

  type response =
    | Errors of Errors.ErrorSet.t
    | StartRecheck
    | EndRecheck
    | AutocompleteResult of (autocomplete_response * (* request id *) int)
end
