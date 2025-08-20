import React from "react";

type Props = {
  msg: string;
};

export default (props: Props) => (
    <div style={{ color: 'red' }}>Error: {props.msg}</div>
);