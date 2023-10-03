%%% Copyright (c) 2021 Łukasz Niemier <lukasz@niemier.pl>
%%% All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions
%%% are met:
%%%
%%% 1. Redistributions of source code must retain the above copyright
%%%    notice, this list of conditions and the following disclaimer.
%%% 2. Redistributions in binary form must reproduce the above copyright
%%%    notice, this list of conditions and the following disclaimer in
%%%    the documentation and/or other materials provided with the
%%%    distribution.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%%% FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
%%% COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
%%% INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
%%% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
%%% LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
%%% ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%%% POSSIBILITY OF SUCH DAMAGE.

-module(brotli_decoder).

-export([new/0, stream/2]).
-export([is_finished/1, is_used/1]).

-export_type([t/0]).

-opaque t() :: reference().

-spec new() -> t().
new() ->
    brotli_nif:decoder_create().

-spec stream(Decoder :: t(), Data :: iodata()) -> {ok | more, iodata()} | error.
stream(Decoder, IOData) ->
    Data = case IOData of
      D when is_binary(D) -> D;
      D -> list_to_binary(D)
    end,

    consume_data(Decoder, Data, <<>>).

consume_data(Decoder, Data, Acc) ->

    case brotli_nif:decoder_decompress_stream(Decoder, Data) of
        ok ->
            {ok, <<Acc/binary, (take_all_output(Decoder))/binary>>};
        more_input ->
            % we assume all the input is consumed
            {more, <<Acc/binary, (take_all_output(Decoder))/binary>>};

        {more_output, Available} ->
            Acc1 = <<Acc/binary, (take_all_output(Decoder))/binary>>,
            consume_data(Decoder, binary:part(Data, {byte_size(Data), -Available}), Acc1);
        Other ->
            Other
    end.

take_all_output(Decoder) ->
  take_all_output(Decoder, <<>>).

% precondition: Decoder is a valid resource
% Repeatedly calls BrotliDecoderTakeOutput while
% BrotliDecoderHasMoreOutput is true
take_all_output(Decoder, Acc) ->
  % decoder_take_output/decoder_has_more_output can return badarg but
  % only if decoder is not a valid resource
  % this is only called from stream() and the
  % resource will be valid

  Bin = brotli_nif:decoder_take_output(Decoder),
  Acc1 = <<Acc/binary, Bin/binary>>,
  case brotli_nif:decoder_has_more_output(Decoder) of
    true ->
      take_all_output(Decoder, Acc1);
    false ->
      Acc1
  end.

is_finished(Decoder) ->
    brotli_nif:decoder_is_finished(Decoder).

is_used(Decoder) ->
    brotli_nif:decoder_is_used(Decoder).
